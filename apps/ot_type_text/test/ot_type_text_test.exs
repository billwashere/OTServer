defmodule OTTextTest do
  use ExUnit.Case, async: true
  doctest OTText

  setup do
  	  ins = [10, "oh hi"]
      del = [25, %{"d"=>20}]
      op = [10, "oh hi", 10, %{"d"=>20}] # The previous ops composed together

    tc = fn(op, isOwn, cursor, expected) ->
      assert OTText.selectionEq(expected, OTText.transformSelection(cursor, op, isOwn))
      assert OTText.selectionEq(expected, OTText.transformSelection(cursor..cursor, op, isOwn))
    end
    { :ok, from_setup: {ins,del,op,tc} }
  end

  test "sane normalisation" do
    assert [] == OTText.normalize [0]
    assert [] == OTText.normalize [""]
    assert [] == OTText.normalize [%{"d"=>0}]
    assert [] == OTText.normalize [1,1]
    assert [] ==  OTText.normalize [2,0]
    assert ["a"] == OTText.normalize ["a", 100]
    assert ["ab"] == OTText.normalize ["a", "b"]
    assert ["ab"] == OTText.normalize ["ab", ""]
    assert ["ab"] == OTText.normalize [0, "a", 0, "b", 0]
    assert ["a", 1, "b"] == OTText.normalize ["a", 1, "b"]
  end

  test "selectionEq" do
  	  assert OTText.selectionEq  5, 5
      assert OTText.selectionEq  0, 0
      assert false == OTText.selectionEq  0, 1
      assert false == OTText.selectionEq  5, 1

      assert OTText.selectionEq  1..2, 1..2
      assert OTText.selectionEq  2..2, 2..2
      assert OTText.selectionEq  0..0, 0..0
      assert OTText.selectionEq  0..1, 0..1
      assert OTText.selectionEq  1..0, 1..0

      assert false == OTText.selectionEq  1..2, 1..0
      assert false == OTText.selectionEq  0..2, 0..1
      assert false == OTText.selectionEq  1..0, 5..0
      assert false == OTText.selectionEq  1..1, 5..5

      assert OTText.selectionEq  0, 0..0
      assert OTText.selectionEq  1, 1..1
      assert OTText.selectionEq  0..0, 0
      assert OTText.selectionEq  1..1, 1

      assert false == OTText.selectionEq  1, 1..0
      assert false == OTText.selectionEq  0, 0..1
      assert false == OTText.selectionEq  1..2, 1
      assert false == OTText.selectionEq  0..2, 0
  end

  test "transformSelection - shouldn't move a cursor at the start of the inserted text", meta do
  	{_,_,op,tc} = meta[:from_setup]
     tc.(op, false, 10, 10)
  end

  test "transformSelection - move a cursor at the start of the inserted text if its yours", meta do
  	{ins,_,_,tc} = meta[:from_setup]
     tc.(ins, true, 10, 15)
  end

  test "transformSelection - should move a character inside a deleted region to the start of the region", meta do
      {_,del,_,tc} = meta[:from_setup]
      tc.(del, false, 25, 25)
      tc.(del, false, 35, 25)
      tc.(del, false, 45, 25)

      tc.(del, true, 25, 25)
      tc.(del, true, 35, 25)
      tc.(del, true, 45, 25)
  end

  test "shouldn't effect cursors before the deleted region", meta do
  	{_,del,_,tc} = meta[:from_setup]
      tc.(del, false, 10, 10)
  end
    test "pulls back cursors past the end of the deleted region", meta do
    	{_,del,_,tc} = meta[:from_setup]
      tc.(del, false, 55, 35)
  end
    test "teleports your cursor to the end of the last insert or the delete", meta do
    	{ins,del,_,tc} = meta[:from_setup]
      tc.(ins, true, 0, 15)
      tc.(ins, true, 100, 15)
      tc.(del, true, 0, 25)
      tc.(del, true, 100, 25)
end
    test "works with more complicated ops", meta do
    	{_,_,op,tc} = meta[:from_setup]
      tc.(op, false, 0, 0)
      tc.(op, false, 100, 85)
      tc.(op, false, 10, 10)
      tc.(op, false, 11, 16)
  
      tc.(op, false, 20, 25)
      tc.(op, false, 30, 25)
      tc.(op, false, 40, 25)
      tc.(op, false, 41, 26)
  end

 test "compose" do
 	assert OTText.compose([0,"hello"], [5," world "]) == ["hello world "]
 end

 test "apply" do
 	document = OTText.new("ABCDEFG")
 	assert OTText.apply(document, [1," hi ",2,%{"d"=>3}]) == OTText.new("A hi BCG")
 end

end
