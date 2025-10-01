require "webmock"
require "./spec_helper"

module OpenAI
  describe "OpenAI::Audio" do
    it "test transcriptions" do
      client = Client.new(TEST_SECRET)
      parts = ["file", "model", "response_format"]
      WebMock.wrap do
        WebMock.stub(:post, "#{OPENAI_API_DEFAULT_URL}/audio/transcriptions")
          .with(headers: {"Authorization" => "Bearer #{TEST_SECRET}"})
          .to_return do |req|
            HTTP::FormData.parse(req) do |part|
              part.name.in?(parts).should be_true
            end
            HTTP::Client::Response.new(200, body: AUDIO_RES)
          end

        req = TranscriptionRequest.new(AUDIO_SAMPLE)
        res = client.transcription(req)
        res.text.should_not be_nil
      end
    end

    it "test translation" do
      client = Client.new(TEST_SECRET)
      parts = ["file", "model", "response_format"]
      WebMock.wrap do
        WebMock.stub(:post, "#{OPENAI_API_DEFAULT_URL}/audio/translations")
          .with(headers: {"Authorization" => "Bearer #{TEST_SECRET}"})
          .to_return do |req|
            HTTP::FormData.parse(req) do |part|
              part.name.in?(parts).should be_true
            end
            HTTP::Client::Response.new(200, body: AUDIO_RES)
          end

        req = TranscriptionRequest.new(AUDIO_SAMPLE)
        res = client.translation(req)
        res.text.should_not be_nil
      end
    end

    it "test speech (text-to-speech)" do
      client = Client.new(TEST_SECRET)
      # We expect JSON body not multipart
      fake_audio = "ID3\x04\x00\x00" # minimal MP3 header magic bytes
      WebMock.wrap do
        WebMock.stub(:post, "#{OPENAI_API_DEFAULT_URL}/audio/speech")
          .with(headers: {"Authorization" => "Bearer #{TEST_SECRET}"})
          .to_return do |req|
            # ensure it's JSON and contains model + input
            body_io = req.body
            body_str = body_io.is_a?(IO) ? body_io.gets_to_end : body_io.to_s
            body_str.includes?("\"model\"").should be_true
            body_str.includes?("\"input\"").should be_true
            HTTP::Client::Response.new(200, body: fake_audio)
          end

        req = SpeechRequest.new("gpt-4o-mini-tts", "Hello Crystal")
        io = client.speech(req)
        bytes = io.gets_to_end
        bytes.should eq(fake_audio)
      end
    end
  end
end
