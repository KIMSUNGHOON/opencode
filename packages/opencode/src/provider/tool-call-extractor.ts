import { Log } from "@/util/log"

const log = Log.create({ service: "tool-call-extractor" })

interface ExtractedToolCall {
  name: string
  arguments: Record<string, unknown>
}

// Regex patterns matching common model tool call output formats:
//   <tool_call>{"name": "fn", "arguments": {...}}</tool_call>
//   <tools>{"name": "fn", "arguments": {...}}</tools>
//   <tool_call>{"function": {"name": "fn", "arguments": {...}}}</tool_call>
const TOOL_CALL_REGEX = /<(?:tool_call|tools)>\s*([\s\S]*?)\s*<\/(?:tool_call|tools)>/g

function tryParseJSON(str: string): unknown {
  try {
    return JSON.parse(str)
  } catch {
    return null
  }
}

/**
 * Normalize various tool call JSON formats into { name, arguments }.
 */
function normalizeToolCall(obj: unknown): ExtractedToolCall | null {
  if (!obj || typeof obj !== "object") return null
  const o = obj as Record<string, unknown>

  // Format 1: { "name": "fn", "arguments": {...} }
  if (typeof o.name === "string" && o.arguments !== undefined) {
    const args =
      typeof o.arguments === "string" ? tryParseJSON(o.arguments) : o.arguments
    return {
      name: o.name,
      arguments: (args as Record<string, unknown>) ?? {},
    }
  }

  // Format 2: { "type": "function", "function": { "name": "fn", "arguments": {...} } }
  if (o.function && typeof o.function === "object") {
    const fn = o.function as Record<string, unknown>
    if (typeof fn.name === "string") {
      const args =
        typeof fn.arguments === "string"
          ? tryParseJSON(fn.arguments)
          : fn.arguments
      return {
        name: fn.name,
        arguments: (args as Record<string, unknown>) ?? {},
      }
    }
  }

  return null
}

/**
 * Extract tool calls from text content.
 * Detects <tool_call>...</tool_call> and <tools>...</tools> patterns
 * with JSON payloads inside.
 */
export function extractToolCallsFromText(text: string): {
  toolCalls: ExtractedToolCall[]
  remainingText: string
} {
  const toolCalls: ExtractedToolCall[] = []

  TOOL_CALL_REGEX.lastIndex = 0
  let match
  while ((match = TOOL_CALL_REGEX.exec(text)) !== null) {
    const jsonStr = match[1].trim()
    try {
      const parsed = JSON.parse(jsonStr)
      if (Array.isArray(parsed)) {
        for (const item of parsed) {
          const tc = normalizeToolCall(item)
          if (tc) toolCalls.push(tc)
        }
      } else {
        const tc = normalizeToolCall(parsed)
        if (tc) toolCalls.push(tc)
      }
    } catch {
      log.info("tool-call JSON parse failed", {
        snippet: jsonStr.slice(0, 200),
      })
    }
  }

  const remainingText = text.replace(TOOL_CALL_REGEX, "").trim()
  return { toolCalls, remainingText }
}

/**
 * Creates a wrapStream middleware that extracts tool calls from text content.
 *
 * When a model server (SGLang, vLLM, etc.) doesn't have a tool-call-parser
 * configured, models output tool calls as XML text (e.g. <tool_call>...</tool_call>)
 * instead of structured tool_calls in the API response.
 *
 * This middleware intercepts the raw model stream, detects those patterns,
 * and emits proper tool-call events so the AI SDK can execute them.
 *
 * Trade-off: text output is buffered until the text block ends. This causes
 * a brief delay for text-only responses but ensures reliable tool-call
 * extraction for mixed content.
 */
export function createToolCallExtractorMiddleware() {
  return {
    async wrapStream({
      doStream,
    }: {
      doStream: () => Promise<{ stream: ReadableStream; [key: string]: any }>
    }) {
      const result = await doStream()

      let textBuffer = ""
      let textStartEvent: any = null
      let buffering = false
      let didExtract = false

      return {
        ...result,
        stream: result.stream.pipeThrough(
          new TransformStream({
            transform(chunk: any, controller: any) {
              // Start buffering text blocks
              if (chunk.type === "text-start") {
                textBuffer = ""
                textStartEvent = chunk
                buffering = true
                return
              }

              // Accumulate text content
              if (chunk.type === "text-delta" && buffering) {
                textBuffer += chunk.delta
                return
              }

              // Process accumulated text when block ends
              if (chunk.type === "text-end" && buffering) {
                buffering = false

                const { toolCalls, remainingText } =
                  extractToolCallsFromText(textBuffer)

                if (toolCalls.length > 0) {
                  didExtract = true
                  log.info("extracted tool calls from text", {
                    count: toolCalls.length,
                    tools: toolCalls.map((tc) => tc.name),
                  })

                  // Emit remaining non-tool-call text if any
                  if (remainingText) {
                    controller.enqueue(textStartEvent)
                    controller.enqueue({
                      type: "text-delta",
                      id: textStartEvent.id,
                      delta: remainingText,
                    })
                    controller.enqueue({
                      type: "text-end",
                      id: textStartEvent.id,
                    })
                  }

                  // Emit tool-call events for extracted calls
                  for (const tc of toolCalls) {
                    const toolCallId = `tc_${Date.now()}_${Math.random().toString(36).slice(2, 10)}`
                    controller.enqueue({
                      type: "tool-call" as const,
                      toolCallId,
                      toolName: tc.name,
                      input: JSON.stringify(tc.arguments),
                    })
                  }
                } else {
                  // No tool calls found — re-emit buffered text as-is
                  controller.enqueue(textStartEvent)
                  if (textBuffer) {
                    controller.enqueue({
                      type: "text-delta",
                      id: textStartEvent.id,
                      delta: textBuffer,
                    })
                  }
                  controller.enqueue({
                    type: "text-end",
                    id: textStartEvent.id,
                  })
                }

                textBuffer = ""
                textStartEvent = null
                return
              }

              // For finish events, update finishReason if we extracted tool calls
              if (chunk.type === "finish" && didExtract) {
                const finishReason =
                  typeof chunk.finishReason === "string"
                    ? "tool-calls"
                    : {
                        unified: "tool-calls",
                        raw: chunk.finishReason?.raw ?? "extracted",
                      }
                controller.enqueue({
                  ...chunk,
                  finishReason,
                })
                didExtract = false
                return
              }

              // Pass through all other events unchanged
              controller.enqueue(chunk)
            },
          }),
        ),
      }
    },
  }
}
