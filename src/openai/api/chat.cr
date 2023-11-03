require "json"
require "./usage"
require "../stream"

module OpenAI
  enum ChatMessageRole
    # Can be generated by the end users of an application, or set by a developer as an instruction.
    User
    # The system message helps set the behavior of the assistant.
    # GPT 3 does not always pay strong attention to system messages
    System
    # The assistant messages help store prior responses. They can also be written by a developer to help give examples of desired behavior.
    Assistant
    # function
    Function

    def to_s(io : IO) : Nil
      io << to_s
    end

    def to_s : String
      super.downcase
    end
  end

  enum FinishReason
    # API returned complete message, or a message terminated by one of the stop sequences provided via the stop parameter
    Stop
    # Incomplete model output due to max_tokens parameter or token limit
    Length
    # The model decided to call a function
    FunctionCall
    # Omitted content due to a flag from our content filters
    ContentFilter
    # API response still in progress or incomplete
    Null

    def to_s(io : IO) : Nil
      io << to_s
    end

    def to_s : String
      super.underscore
    end
  end

  record Hate, filtered : String, severity : String? do
    include JSON::Serializable
  end
  record SelfHarm, filtered : String, severity : String? do
    include JSON::Serializable
  end
  record Sexual, filtered : String, severity : String? do
    include JSON::Serializable
  end
  record Violence, filtered : String, severity : String? do
    include JSON::Serializable
  end

  record ContentFilterResults, hate : Hate?, self_harm : SelfHarm?, sexual : Sexual?, violence : Violence? do
    include JSON::Serializable
  end

  record PromptAnnotation, prompt_index : Int32?, content_filter_results : ContentFilterResults? do
    include JSON::Serializable
  end

  # The name and arguments of a function that should be called, as generated by the model.
  #
  # The arguments to call the function with, as generated by the model in JSON format. Note that the model does not always generate valid JSON,
  # and may hallucinate parameters not defined by your function schema. Validate the arguments in your code before calling your function.
  record ChatFunctionCall, name : String, arguments : JSON::Any do
    include JSON::Serializable
  end

  class ChatFunction
    include JSON::Serializable

    # The name of the function to be called. Must be a-z, A-Z, 0-9, or contain underscores and dashes, with a maximum length of 64.
    property name : String

    # A description of what the function does, used by the model to choose when and how to call the function.
    property description : String? = nil

    # The parameters the functions accepts, described as a JSON Schema object. See the guide for examples, and the JSON Schema reference for documentation about the format.
    # To describe a function that accepts no parameters, provide the value {"type": "object", "properties": {}}.
    property parameters : JSON::Any

    def initialize(@name, @parameters, @description = nil)
    end
  end

  struct ChatMessage
    include JSON::Serializable

    # The role of the messages author. One of system, user, assistant, or function.
    getter role : ChatMessageRole

    # The contents of the message. content is required for all messages, and may be null for assistant messages with function calls.
    @[JSON::Field(emit_null: true)]
    getter content : String?

    # The name of the author of this message. name is required if role is function, and it should be the name of the function
    # whose response is in the content. May contain a-z, A-Z, 0-9, and underscores, with a maximum length of 64 characters.
    getter name : String?

    # The name and arguments of a function that should be called, as generated by the model.
    getter function_call : ChatFunctionCall?

    @[JSON::Field(ignore: true)]
    property tokens : Int32 = 0

    def initialize(@role, @content = nil, @name = nil, @function_call = nil, @tokens = 0)
    end
  end

  class ChatCompletionRequest
    include JSON::Serializable

    def initialize(@model, @messages, @max_tokens = nil, @temperature = 1.0, @top_p = 1.0,
                   @stream = false, @stop = nil, @presence_penalty = 0.0, @frequency_penalty = 0.0,
                   @logit_bias = nil, @user = nil, @functions = nil, @function_call = nil)
    end

    # the model id
    property model : String

    # A list of messages comprising the conversation so far
    property messages : Array(ChatMessage)

    # The maximum number of tokens to generate in the chat completion.
    # The total length of input tokens and generated tokens is limited by the model's context length.
    property max_tokens : Int32?

    # What sampling temperature to use, between 0 and 2.
    # Higher values like 0.8 will make the output more random,
    # while lower values like 0.2 will make it more focused and deterministic.
    property temperature : Float64 = 1.0

    # An alternative to sampling with temperature, called nucleus sampling,
    # where the model considers the results of the tokens with top_p probability mass.
    # So 0.1 means only the tokens comprising the top 10% probability mass are considered.
    # Alter this or temperature but not both.
    property top_p : Float64 = 1.0

    # How many completions to generate for each prompt.
    @[JSON::Field(key: "n")]
    property num_completions : Int32 = 1

    # Whether to stream back partial progress.
    # If set, partial message deltas will be sent, like in ChatGPT.
    # Tokens will be sent as data-only server-sent events as they become available, with the stream terminated by a data: [DONE]
    property stream : Bool = false

    # Up to 4 sequences where the API will stop generating further tokens.
    # The returned text will not contain the stop sequence.
    property stop : String | Array(String)? = nil

    # Number between -2.0 and 2.0.
    # Positive values penalize new tokens based on whether they appear in the text so far,
    # increasing the model's likelihood to talk about new topics.
    property presence_penalty : Float64 = 0.0

    # Number between -2.0 and 2.0.
    # Positive values penalize new tokens based on their existing frequency in the text so far,
    # decreasing the model's likelihood to repeat the same line verbatim.
    property frequency_penalty : Float64 = 0.0

    # Modify the likelihood of specified tokens appearing in the completion.
    # You can use this [tokenizer tool](https://platform.openai.com/tokenizer?view=bpe) (which works for both GPT-2 and GPT-3) to convert text to token IDs
    property logit_bias : Hash(String, Float64)? = nil

    # A unique identifier representing your end-user, which can help OpenAI to monitor and detect abuse.
    property user : String? = nil

    # A list of functions the model may generate JSON inputs for.
    property functions : Array(ChatFunction)? = nil

    # Controls how the model responds to function calls. none means the model does not call a function, and responds to the end-user.
    # auto means the model can pick between an end-user or calling a function. Specifying a particular function via {"name": "my_function"}
    # forces the model to call that function. none is the default when no functions are present. auto is the default if functions are present.
    property function_call : String | JSON::Any? = nil
  end

  record ChatCompletionChoice, index : Int32, message : ChatMessage, finish_reason : FinishReason do
    include JSON::Serializable
  end

  struct ChatCompletionResponse
    include JSON::Serializable

    # A unique identifier for the chat completion.
    getter id : String

    # The object type, which is always chat.completion.
    getter object : String

    # The Unix timestamp (in seconds) of when the chat completion was created.
    @[JSON::Field(converter: Time::EpochConverter)]
    getter created : Time

    # The model used for the chat completion.
    getter model : String

    # A list of chat completion choices. Can be more than one if n is greater than 1.
    getter choices : Array(ChatCompletionChoice)

    # Usage statistics for the completion request.
    getter usage : Usage
  end

  record ChatCompletionStreamChoiceDelta, role : ChatMessageRole?, content : String?, function_call : ChatFunctionCall? do
    include JSON::Serializable
  end
  record ChatCompletionStreamChoice, index : Int32, delta : ChatCompletionStreamChoiceDelta?, finish_reason : FinishReason, content_filter_results : ContentFilterResults? do
    include JSON::Serializable
  end

  struct ChatCompletionStreamResponse
    include JSON::Serializable

    # A unique identifier for the chat completion.
    getter id : String

    # The object type, which is always chat.completion.
    getter object : String

    # The Unix timestamp (in seconds) of when the chat completion was created.
    @[JSON::Field(converter: Time::EpochConverter)]
    getter created : Time

    # The model used for the chat completion.
    getter model : String

    # A list of chat completion choices. Can be more than one if n is greater than 1.
    getter choices : Array(ChatCompletionStreamChoice)

    getter prompt_annotations : Array(PromptAnnotation)?
  end

  class ChatCompletionStream < StreamReader(ChatCompletionStreamResponse)
  end

  # `OpenAI::FunctionExecutor` is a helper class which try to hide the details of object casting, JSON Schema generation
  # Being able to deal any User defined Types, it requires ADT to extend `OpenAI::FuncMarker` a marker module.
  # And requires Block to accept and return Types as `JSON::Serializable`
  class FunctionExecutor
    alias Callback = JSON::Serializable -> JSON::Serializable
    getter functions : Array(ChatFunction)

    def initialize
      @functions = Array(ChatFunction).new
      @map = Hash(String, {FuncMarker, Callback}).new
    end

    def add(name : String, description : String?, clz : U, &block : Callback) forall U
      func = ChatFunction.new(name: name, description: description, parameters: JSON.parse(clz.json_schema.to_json))
      functions << func
      @map[name] = {clz, block}
    end

    def execute(call : ChatFunctionCall)
      # sometime the chat defines the name: "functions.function_name" so we should check for that case
      raise OpenAIError.new "Function '#{call.name}' not defined." unless func = @map[call.name]? || @map[call.name.split('.', 2)[-1]]?
      params = call.arguments.as_s? || call.arguments.to_s
      arg = func.first.from_json(params)
      result = func.last.call(arg)
      ChatMessage.new(:function, result.to_pretty_json, call.name)
    end
  end
end
