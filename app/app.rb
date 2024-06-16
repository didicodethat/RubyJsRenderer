require 'json'

DEBUGGING = ENV["DEBUGGING"] == "true"

def assert assertion, message
  raise message if !assertion
end

class Expression
  attr_accessor :list
  attr_accessor :semi_colon
  attr_accessor :line_break_after
  def initialize *list
    @list = list
    @semi_colon = true
    @line_break_after = true
  end

  def no_line_break_after!
    @line_break_after = false
    return self
  end

  def no_semi_colon!
    @semi_colon = false
    return self
  end

  def line_break_after!
    @line_break_after = true
    return self
  end

  def semi_colon!
    @semi_colon = true
    return self
  end

  def << arg
    @list << arg
  end

  def render
    list.map do |item|
      if item.is_a?(Symbol)
        item.to_s
      elsif item.is_a?(Expression)
        item.render
      else
        item.to_json
      end
    end.join(" ") + "#{@semi_colon ? ";" : ""}#{@line_break_after ? "\n" : ""}"
  end
end

class Context
  def initialize
    @stack = []
  end

  def e(*list)
    @stack << Expression.new(*list)
    return @stack.last
  end

  def curly(&content)
    e(:"{").no_semi_colon!
    yield self
    e(:"}").no_semi_colon!
  end

  def args(*args)
    expr = e(:"(")
    args.each.with_index do |arg, k|
      assert(arg.is_a?(Symbol), "arguments should be symbols") if DEBUGGING
      expr.list << arg
      expr.list << :", " if k < args.length - 1
    end 
    expr.list << :")"
    expr.no_semi_colon!.no_line_break_after!
  end

  ## Defines a variable
  def let(var_name, value)
    assert(var_name.is_a?(Symbol), "the name of a variable should be a symbol") if DEBUGGING
    e(:let, var_name, :"=", value)
  end

  ## Defines a constant
  def const(const_name, value)
    assert(const_name.is_a?(Symbol), "the name of a constant should be a symbol") if DEBUGGING
    e(:const, const_name, :"=", value)
  end

  ## Defines a function
  def func(fn_name, *args, &body)
    assert(fn_name.is_a?(Symbol), "the name of the function should be a symbol") if DEBUGGING
    e(:function, fn_name).no_semi_colon!.no_line_break_after!
    args(*args)
    curly(&body)
  end

  # doesn't add to the stack
  def sum!(*args)
    expr = Expression.new()
    args.each.with_index do |arg, k|
      expr << arg
      expr << :+ if k < args.length - 1
    end
    expr.no_semi_colon!.no_line_break_after!
  end

  def call(fn_name, *args)
    expr = e(fn_name, :"(")
    args.each.with_index do |arg, k|
      expr << arg
      expr << :"," if k < args.length - 1
    end
    expr << :")"
    expr
  end

  def return(*args)
    e(:return, *args)
  end

  def render
    @stack.map(&:render).join("")
  end
end

js = Context.new

js.let(:name, "cool")
js.const(:yachoo, "not cool")
js.func(:functionName, :a, :b, :c) do |c|
  c.let(:anotherVar, 10)
  c.return(c.sum!(:a, :b, :c, :anotherVar))
end

js.call(:functionName, 20, 30, 40)

puts js.render