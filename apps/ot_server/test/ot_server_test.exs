defmodule OTServerTest do
  use ExUnit.Case, async: true
  doctest OTServer

  defp simple(module) do
  	#document = module.new("ABCDEFG")
  	#module.apply(document, [1," hi ",2,%{"d"=>3}]) == module.new("A hi BCG")
  end

  test "the truth" do
   model = OTServer.newModel
   OTServer.regristerType(model,OTText)
   {_, server} =  OTServer.new(model)
   #assert OTServer.get(bucket) == 0	
   #document = OTText.new("ABCDEFG")
   #assert OTText.apply(document, [1," hi ",2,%{"d"=>3}]) == OTText.new("A hi BCG")
   #simple(OTText)
  end
end
