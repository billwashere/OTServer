defmodule OTServerModel do
defstruct typemap: %{}
end
defmodule OTServer do


  def regristerType(config,typen) do
  	Map.put(config.typemap,(typen.new).ottype,typen)
  end

  def newModel do
  	%OTServerModel{}
  end


  def new do
    Agent.start_link(fn -> 0 end)
  end

  def new(config) do
    Agent.start_link(fn -> 0 end)
  end

  def click(pid) do
    Agent.get_and_update(pid, fn(n) -> {n + 1, n + 1} end)
  end

  def set(pid, new_value) do
    Agent.update(pid, fn(_n) -> new_value end)
  end

  def get(pid) do
    Agent.get(pid, fn(n) -> n end)
  end
end
