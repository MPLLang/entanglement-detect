structure CLA = CommandLineArgs

val n = CLA.parseInt "n" 100
val m = CLA.parseInt "m" 1000000

val data = Array.array (2*n, "")

fun loopEven x i j =
  if j >= m then x
  else loopOdd (Array.sub (data, 2*i)) i (j+1)

and loopOdd x i j =
  if j >= m then x
  else loopEven (Array.sub (data, 2*i+1)) i (j+1)

fun put i = Array.update (data, i, Int.toString i)

fun bench () =
  let
    fun go i = (put (2*i); put (2*i+1); loopEven "" i 0)
  in
    SeqBasis.tabulate 1 (0, n) go
  end

val result = Benchmark.run "stress detect" bench
val _ = print (Array.sub (result, 0) ^ " " ^ Array.sub (result, 1) ^ "\n")

val _ = GCStats.report ()
