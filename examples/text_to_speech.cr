require "../src/openai"

# Simple Text-To-Speech example
# Exports an mp3 file using gpt-4o-mini-tts model
# Usage:
#   export OPENAI_API_KEY=sk-... && crystal run examples/text_to_speech.cr

client = OpenAI::Client.new

req = OpenAI::SpeechRequest.new(
  "gpt-4o-mini-tts",
  "Today is a wonderful day to build something people love!",
  voice: "coral",
  instructions: "Speak in a cheerful and positive tone.",
  response_format: "mp3"
)

io = client.speech(req)
File.write("speech.mp3", io.gets_to_end)
puts "Saved speech.mp3"