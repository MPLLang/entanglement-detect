structure CLA = CommandLineArgs

val n = CLA.parseInt "n" 100
val m = CLA.parseInt "m" 1000000

fun loopEven x y j =
  if j >= m then x
  else loopOdd y x (j+1)

and loopOdd x y j =
  if j >= m then x
  else loopEven y x (j+1)

fun bench () =
  let
    fun go i = loopEven (Int.toString (2*i)) (Int.toString (2*i+1)) 0
  in
    SeqBasis.tabulate 1 (0, n) go
  end

val result = Benchmark.run "stress detect" bench
val _ = print (Array.sub (result, 0) ^ " " ^ Array.sub (result, 1) ^ "\n")

val _ = GCStats.report ()
