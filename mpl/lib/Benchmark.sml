structure Benchmark =
struct

  fun getTimes msg n f =
    let
      fun loop tms n =
        let
          val (result, tm) = Util.getTime f
        in
          print (msg ^ " " ^ Time.fmt 4 tm ^ "s\n");

          if n <= 1 then
            (result, List.rev (tm :: tms))
          else
            loop (tm :: tms) (n-1)
        end
    in
      loop [] n
    end

  fun run msg f =
    let
      val warmup = Time.fromReal (CommandLineArgs.parseReal "warmup" 0.0)
      val rep = CommandLineArgs.parseInt "repeat" 1
      val _ =
        if rep >= 1 then ()
        else Util.die "-repeat N must be at least 1"

      val _ = print ("warmup " ^ Time.fmt 4 warmup ^ "\n")
      val _ = print ("repeat " ^ Int.toString rep ^ "\n")

      fun warmupLoop startTime =
        if Time.>= (Time.- (Time.now (), startTime), warmup) then
          () (* warmup done! *)
        else
          let
            val (_, tm) = Util.getTime f
          in
            print ("warmup_run " ^ Time.fmt 4 tm ^ "s\n");
            warmupLoop startTime
          end

      val _ =
        if Time.<= (warmup, Time.zeroTime) then ()
        else ( print ("====== WARMUP ======\n" ^ msg ^ "\n")
             ; warmupLoop (Time.now ())
             ; print ("==== END WARMUP ====\n")
             )

      val _ = print (msg ^ "\n")

      val sm0 = GCStats.susMarks ()
      val ec0 = GCStats.eChecks ()
      val t0 = Time.now ()
      val (result, tms) = getTimes "time" rep f
      val t1 = Time.now ()
      val sm1 = GCStats.susMarks ()
      val ec1 = GCStats.eChecks ()

      val endToEnd = Time.- (t1, t0)
      val sm = sm1 - sm0
      val ec = ec1 - ec0

      val averageSM = sm div (LargeInt.fromInt rep)
      val averageEC = ec div (LargeInt.fromInt rep)

      val total = List.foldl Time.+ Time.zeroTime tms
      val avg = Time.toReal total / (Real.fromInt rep)
    in
      print "\n";
      print ("average " ^ Real.fmt (StringCvt.FIX (SOME 4)) avg ^ "s\n");
      print ("total   " ^ Time.fmt 4 total ^ "s\n");
      print ("end-to-end " ^ Time.fmt 4 endToEnd ^ "s\n");
      print ("tot-sus-mark " ^ LargeInt.toString sm ^ "\n");
      print ("tot-e-check " ^ LargeInt.toString ec ^ "\n");
      print ("avg-sus-mark " ^ LargeInt.toString averageSM ^ "\n");
      print ("avg-e-check " ^ LargeInt.toString averageEC ^ "\n");
      result
    end

end
