defmodule OTTextDocument do
defstruct data: "", ottype: "text"
end

defmodule OTText do
def new do %OTTextDocument{} end
def new(initial), do: %OTTextDocument{data: initial}
def apply(document,op) do
	checkOp(op)
	state = {document,0}
	{doc,_} = List.foldl(op, state, fn (x, acc) -> cond do
		is_number(x) ->
			{s,p} = acc
			{s,p+x}
		is_binary(x) ->
			{s,p} = acc
			{head,tail} = String.split_at s.data, p
			acc = {new(head <> x <> tail),p+String.length x}
			acc
		is_map(x) ->
			{s,p} = acc
			{head,otail} = String.split_at s.data, p
			todel = Map.get(x,"d")
			tail = String.slice(otail, todel, String.length otail)
			acc = {new(head <> tail),p-todel}
			acc
		true ->
			acc
		end
	 end)
	 doc

end
def trim(op) do
  if (length op) > 0 && is_number(List.last op) do
    op = List.delete_at(op,-1)
  end
  op
  
end

def appender(component,op) do
	#IO.inspect op
	last = List.last op
	cond do
	is_map(component) && Map.get(component,"d") === 0 ->
		op
	is_map(component) && Map.get(component,"d") > 0 && is_map(List.last op) ->
		last = List.last op
		op = List.delete_at(op,-1)
		last = %{ last | "d" => Map.get(last,"d") + Map.get(component,"d") }
		op <> (last + component)
		op	
	is_number(component) && component ==0 ->
		op
	length(op) == 0 && is_binary(component) && String.length("" <> component) > 0 ->
		op = op ++ [component]
		op
	length(op) == 0 && is_binary(component) && String.length("" <> component) == 0 ->
		op	
	is_number(last) == is_number(component) && is_number(last) == true ->
		op = List.delete_at(op,-1)
		op = op ++ [(last + component)]
		op
	is_binary(last) == is_binary(component) && is_binary(last) == true ->
		op = List.delete_at(op,-1)
		op = op ++ [(last <> component)]
		op
	true ->
		op = op ++ [component]
		op
	end
	op
end

#{payload, idx, offset, indivisableField,op}
def take_op(op,n,indivisableField,idx, offset ) do
	if (idx === length op) do
     	if(n === -1) do
     		{nil,{}}
     	else 
     		{:ok,n}
     	end
    else
		c = Enum.at(op,idx)
		cond do
		is_number(c) && (n === -1 || c - offset <= n) ->
			{:ok,{c - offset,idx+1,0}}
		is_number(c) && !(n === -1 || c - offset <= n) ->
			{:ok,{n,idx,offset+n}}
		is_binary(c) && (n === -1 || indivisableField === 'i' || ((String.length c) - offset) <= n) ->
			{:ok,{(String.slice c, offset, (String.length c)),idx+1,0}}
		is_binary(c) && !(n === -1 || indivisableField === 'i' || ((String.length c) - offset) <= n) ->
			{:ok,{(String.slice c, offset, (offset + n)),idx+1,offset+n}}
		is_map(c) == true && (n === -1 || indivisableField === 'd' || (Map.get(c,"d") - offset) <= n) ->
			{:ok,{%{"d" => Map.get(c,"d") - offset}, idx+1, 0}}
		is_map(c) == true && !(n === -1 || indivisableField === 'd' || (Map.get(c,"d") - offset) <= n) ->
			{:ok,{%{"d" => n}, idx, offset}}
		true ->
			raise ArgumentError, message: "Unknown element in op"
		end
	end	
end

def checkOp(op) when is_list(op) do
	checker = fn (x, acc) -> cond do
		is_number(x) ->
			if (x <= 0) do
				raise ArgumentError, message: "Op has negative number"
			end
			if (is_number(acc)) do
				raise ArgumentError, message: "Op has a trailing skip"
			end
			x
		is_binary(x) && String.length(""<>x) == 0 ->
				raise ArgumentError, message: "Inserts can not be empty"
		is_binary(x) && String.length(""<>x) != 0 ->
			x
		is_map(x) && Map.get(x,"d") <= 0 ->
				raise ArgumentError, message: "Inserts can not be empty"
		is_map(x) && Map.get(x,"d") > 0 ->
			x
		true ->
			raise ArgumentError, message: "Unknown element in op"
		end
		x
		end
	Enum.reduce op, checker
end

def normalize(op) do          
	newOp = List.foldl(op, [], &appender/2)
	newOp = trim newOp
	newOp
end

def componentLength(x) when is_number(x) do x end
def componentLength(x) when is_binary(x) do String.length x end
def componentLength(x) when is_map(x) do Map.get(x,"d") end

def reduce_range(collection, range, acc, fun) do
	Enum.reduce(Enum.slice(collection,range),acc,fun)
end

defp number_compose(chunks, op, length,idx, offset) when length > 0 do
	{_,{chunk,idx,offset}} = take_op(op,length, 'd',idx, offset);
	chunks = chunks ++ [chunk]
	if (is_map(chunk) == false) do
		length = length - componentLength(chunk);
	end
	number_compose(chunks,op,length,idx, offset)
end

defp number_compose(chunks,_,_,idx, offset) do {chunks,idx, offset } end

defp map_compose(chunks, op, length,idx, offset) when length > 0 do
	{_,{chunk,idx,offset}} = take_op(op,length, 'd',idx, offset);
	cond do
	is_number(chunk) ->
		chunks = chunks ++ [%{"d" => chunk}]
		length = length - chunk
	is_binary(chunk) ->
		length = length - String.length chunk
	is_map(chunk) ->
		chunks = chunks ++ [chunk]
	end
	map_compose(chunks,op,length,idx, offset)
end

defp map_compose(chunks,_,_,idx, offset) do {chunks,idx, offset } end

defp map_transform(chunks, op, length,idx, offset) when length > 0 do
	{_,{chunk,idx,offset}} = take_op(op,length, 'i',idx, offset);
	cond do
	is_number(chunk) ->
		length = length - chunk
	is_binary(chunk) ->
		chunks = chunks ++ [chunk]
	is_map(chunk) ->
		length = length - componentLength(chunk)
	end
	map_transform(chunks,op,length,idx, offset)
end

defp map_transform(chunks,_,_,idx, offset) do {chunks,idx, offset } end

defp number_transform(chunks, op, length,idx, offset) when length > 0 do
	{_,{chunk,idx,offset}} = take_op(op,length, 'i',idx, offset);
	chunks = chunks ++ [chunk]
	if (is_binary(chunk) == false) do
		length = length - componentLength(chunk);
	end
	number_transform(chunks,op,length,idx, offset)
end

defp number_transform(chunks,_,_,idx, offset) do {chunks,idx, offset } end

defp extra_take(chunks, op, idx, offset) do
	{ok,res} = take_op(op,-1,'',idx, offset)
	if(ok != nil) do
		{chunk,idx,offset} = res
		chunks = chunks ++ [chunk]
		extra_take(chunks,op,idx, offset)
	else
		chunks
	end
end


def transform(op1,op2,side) do
	checkOp(op1)
	checkOp(op2)
	op = []
	idx = 0
	offset = 0
	default = {op,idx, offset}
	transformer = fn (x, acc) ->
	cond do	
		is_number(x) ->
			length = x;
			{op,idx, offset} = acc
			{op,idx, offset } = number_transform(op,op1,length,idx, offset)
			acc = {op,idx, offset}
			{:cont,acc}
		is_binary(x) ->
			{op,idx, offset} = acc
			if (side == 'left') do
          		#The left insert should go first.
          		if (is_binary(op[idx])) do
            		{ok,res} = take_op(op,-1,'',idx, offset)
					if(ok != nil) do
						{chunk,idx,offset} = res
						op = op ++ [chunk]
					end
          		end
        	end

        	#Otherwise skip the inserted text.
        	op = op ++ [String.length x]
			acc = {op,idx, offset}
			{:cont,acc}
		is_map(x) ->
			length = Map.get(x,"d")
			{op,idx, offset} = acc
			{op,idx, offset } = map_transform(op,op1,length,idx, offset)
			acc = {op,idx, offset}
			{:cont,acc}
		true ->
			{:cont,acc}
		end
	end

	{op,idx, offset} = Enumerable.reduce(op2, {:cont, default}, transformer) |> elem(1)
	op = extra_take(op,op1,idx, offset)       
	newOp = normalize(op)
	newOp
end

def compose(op1,op2) do
	checkOp(op1)
	checkOp(op2)
	state = {[],0,0}
	{op,idx, offset} = List.foldl(op2, state, fn (x, acc) -> 	cond do
		is_number(x) ->
			length = x;
			{op,idx, offset} = acc
			{op,idx, offset } = number_compose(op,op1,length,idx, offset)
			acc = {op,idx, offset}
			acc
		is_binary(x) ->
			{op,idx, offset} = acc
			op = op ++ [x]
			acc = {op,idx, offset}
			acc
		is_map(x) ->
			length = Map.get(x,"d")
			{op,idx, offset} = acc
			{op,idx, offset } = map_compose(op,op1,length,idx, offset)
			acc = {op,idx, offset}
			acc
		true ->
			acc
		end
	end)
	op = extra_take(op,op1,idx, offset)       
	newOp = normalize(op)
	newOp
end

def selectionEq(c1,%Range{} = c2) when is_number(c1) do
	(c1 == c2.first) &&  (c1 == c2.last)
end

def selectionEq(%Range{} = c1,c2) when is_number(c2) do
	selectionEq(c2,c1)
end

def selectionEq(c1,c2) do
	c1 == c2
end

defp transformPosition(cursor, op) do
	pos = 0
	trans = fn (x, {pos,cursor}) ->
		if (cursor <= pos) do {:halt, {pos,cursor}}
	else
	cond do	
		is_number(x) && cursor <= pos + x ->
			{:halt,{cursor,cursor}}
		is_number(x) && (cursor <= pos + x) == false ->
			{:cont,{pos + x,cursor}}
		is_binary(x) ->
        	cursor = cursor + String.length x
        	pos = pos + String.length x
        	{:cont, {pos,cursor}}
		is_map(x) ->
			cursor = cursor - min(Map.get(x,"d"), cursor - pos)
			{:cont,{pos,cursor}}
		true ->
			{:cont,{pos,cursor}}
		end
	end
	end

	Enumerable.reduce(op, {:cont, {pos,cursor}}, trans) |> elem(1) |> elem(1)
end

def transformSelection(selection, op, isOwnOp) do
	if(isOwnOp) do
		List.foldl(op, 0, fn (x, pos) -> 	cond do
			is_number(x) ->
				pos + x
			is_binary(x) ->
				pos + String.length x
			true ->
				pos
			end
		end)
	else
		cond do
			is_number(selection) ->
				 transformPosition(selection, op)
			true ->
				transformPosition(selection.first, op)..transformPosition(selection.last, op)
		end
	end
end
end
