structure DelaunayTriangulation :
sig
  val triangulate: Geometry2D.point Seq.t -> int * Topology2D.mesh
end =
struct

  structure CLA = CommandLineArgs

  val showDelaunayRoundStats = CLA.parseFlag "show-delaunay-round-stats"
  val maxBatchDiv = CLA.parseInt "max-batch-divisor" 10
  val reserveGrain = CLA.parseInt "reserve-grain" 20
  val ripAndTentGrain = CLA.parseInt "rip-and-tent-grain" 20
  val initialThreshold = CLA.parseInt "init-threshold" 10000
  val nnRebuildFactor = CLA.parseReal "nn-rebuild-factor" 10.0
  val batchSizeFrac = CLA.parseReal "batch-frac" 0.035

  val reportTimes = CLA.parseFlag "report-delaunay-times"

  structure G = Geometry2D
  structure T = Topology2D
  structure NN = NearestNeighbors
  structure A = Array
  structure AS = ArraySlice
  structure DSeq = DelayedSeq

  type vertex = T.vertex
  type simplex = T.simplex

  val BOUNDARY_SIZE = 10

  fun generateBoundary pts =
    let
      val p0 = Seq.nth pts 0
      val minCorner = Seq.reduce G.Point.minCoords p0 pts
      val maxCorner = Seq.reduce G.Point.maxCoords p0 pts
      val diagonal = G.Point.sub (maxCorner, minCorner)
      val size = G.Vector.length diagonal
      val stretch = 10.0
      val radius = stretch*size
      val center = G.Vector.add (minCorner, G.Vector.scaleBy 0.5 diagonal)

      val vertexInfo =
        { numVertices = Seq.length pts + BOUNDARY_SIZE
        , numBoundaryVertices = BOUNDARY_SIZE
        }

      val circleInfo =
        {center=center, radius=radius}
    in
      T.initialMeshWithBoundaryCircle vertexInfo circleInfo
    end


  (* fun initialMesh pts =
    let
      val mesh = generateBoundary pts

      val totalNumVertices = T.numVertices boundaryMesh + Seq.length pts
      val totalNumTriangles = T.numTriangles boundaryMesh + 2 * (Seq.length pts)

      val mesh =
        T.new {numVertices = totalNumVertices, numTriangles = totalNumTriangles}
    in
      T.copyData {src = boundaryMesh, dst = mesh};

      (mesh, T.numVertices boundaryMesh, T.numTriangles boundaryMesh)
    end *)


  fun writeMax a i x =
    let
      fun loop old =
        if x <= old then () else
        let
          val old' = Concurrency.casArray (a, i) (old, x)
        in
          if old' = old then ()
          else loop old'
        end
    in
      loop (A.sub (a, i))
    end


  fun dsAppend (s, t) =
    DSeq.tabulate (fn i =>
        if i < Seq.length s then
          Seq.nth s i
        else
          Seq.nth t (i - Seq.length s))
      (Seq.length s + Seq.length t)


  type timers = (string * real ref) list
  val timers =
    [ ("reserve", ref 0.0)
    , ("rip-and-tent", ref 0.0)
    , ("split", ref 0.0)
    , ("nn-rebuild", ref 0.0)
    ]

  fun clearTimers () =
    List.app (fn (_, t) => t := 0.0) timers

  fun updateTimer timers (name, tm) =
    case timers of
      [] => ()
    | (s, t) :: rest =>
        if name = s then
          t := (!t + Time.toReal tm)
        else
          updateTimer rest (name, tm)
  val updateTimer = updateTimer timers

  fun timed name f =
    if not reportTimes then f () else
    let
      val (result, tm) = Util.getTime f
    in
      updateTimer (name, tm);
      result
    end

  fun getTimer timers name =
    case timers of
      [] => 0.0
    | (s, t) :: rest => if s = name then !t else getTimer rest name
  val getTimer = getTimer timers

  fun timerSum () =
    List.foldl (fn ((_, tm), t) => t + !tm) 0.0 timers


  type nn = (Geometry2D.point -> vertex)


  fun triangulate inputPts =
    let
      val t0 = Time.now ()

      val maxBatch = Util.ceilDiv (Seq.length inputPts) maxBatchDiv
      val mesh = generateBoundary inputPts
      val totalNumVertices = T.numVertices mesh

      val reserved =
        SeqBasis.tabulate 10000 (0, totalNumVertices) (fn _ => ~1)

      val allVertices = Seq.tabulate (fn i => i) (Seq.length inputPts)

      fun nearestSimplex nn pt =
        (T.triangleOfVertex mesh (nn pt), 0)

      fun singleInsert start (id, pt) =
        let
          val center = #1 (T.findPoint mesh pt start)
        in
          T.ripAndTentCavity mesh center (id, pt) (2*id, 2*id+1)
        end

      fun singleInsertLookupStart nn id =
        let
          val pt = Seq.nth inputPts id
        in
          singleInsert (nearestSimplex nn pt) (id, pt)
        end

      fun batchInsert (nn: nn) (vertsToInsert: vertex DSeq.t) =
        let
          val m = DSeq.length vertsToInsert

          val centers = timed "reserve" (fn _ =>
            AS.full (SeqBasis.tabulate reserveGrain (0, m) (fn i =>
              let
                val id = DSeq.nth vertsToInsert i
                val pt = Seq.nth inputPts id
                val center =
                  #1 (T.findPoint mesh pt (nearestSimplex nn pt))
                val _ =
                  T.loopPerimeter mesh center pt ()
                    (fn (_, v) => writeMax reserved v id)
              in
                center
              end)))

          val winnerFlags = timed "rip-and-tent" (fn _ =>
            AS.full (SeqBasis.tabulate ripAndTentGrain (0, m) (fn i =>
              let
                val id = DSeq.nth vertsToInsert i
                val pt = Seq.nth inputPts id
                val center = Seq.nth centers i
                val isWinner =
                  T.loopPerimeter mesh center pt true
                    (fn (allMine, v) =>
                      if A.sub (reserved, v) = id then
                        (A.update (reserved, v, ~1); allMine)
                      else
                        false)
              in
                if not isWinner then () else
                  (** rip-and-tent needs to create 1 new vertex and 2 new
                    * triangles. The new vertex is `id`, and the new triangles
                    * are respectively `2*id` and `2*id+1`. This ensures unique
                    * names.
                    *)
                  T.ripAndTentCavity mesh center (id, pt) (2*id, 2*id+1);

                isWinner
              end)))

          val {true=winners, false=losers} = timed "split" (fn _ =>
            Split.split vertsToInsert (DSeq.fromArraySeq winnerFlags))
        in
          (winners, losers)
        end

      fun shouldRebuild numNextRebuild numDone =
        let
          val n = Seq.length inputPts
        in
          numDone >= numNextRebuild
          andalso
          numDone <= Real.floor (Real.fromInt n / nnRebuildFactor)
        end

      fun buildNN (done: vertex Seq.t) =
        let
          val pts = Seq.map (Seq.nth inputPts) done
          val tree = NN.makeTree 16 pts
        in
          (fn pt => Seq.nth done (NN.nearestNeighbor tree pt))
        end

      fun doRebuildNN numNextRebuild doneVertices =
        let
          val nn = timed "nn-rebuild" (fn _ => buildNN doneVertices)
          val numNextRebuild =
            Real.ceil (Real.fromInt numNextRebuild * nnRebuildFactor)
        in
          if not showDelaunayRoundStats then () else
          print ("rebuilt nn; next rebuild at " ^ Int.toString numNextRebuild ^ "\n");

          (nn, numNextRebuild)
        end


      (** start by inserting points one-by-one until mesh is large enough *)
      fun smallLoop numDone (nn, numNextRebuild) remaining =
        if numDone >= initialThreshold orelse Seq.length remaining = 0 then
          (numDone, nn, numNextRebuild, remaining)
        else
          let
            val (id, remaining) =
              (Seq.nth remaining 0, Seq.drop remaining 1)
            val _ = singleInsertLookupStart nn id
            val numDone = numDone+1

            val (nn, numNextRebuild) =
              if not (shouldRebuild numNextRebuild numDone) then
                (nn, numNextRebuild)
              else
                doRebuildNN numNextRebuild (Seq.take allVertices numDone)
          in
            smallLoop numDone (nn, numNextRebuild) remaining
          end


      fun loop numRounds (done, numDone) (nn, numNextRebuild) losers remaining =
        if numDone = Seq.length inputPts then
          numRounds
        else
          let
            val numRetry = Seq.length losers
            val totalRemaining = numRetry + Seq.length remaining
            (* val numDone = Seq.length inputPts - totalRemaining *)
            val desiredSize =
              Int.min (maxBatch, Int.min (totalRemaining,
                1 + Real.round (Real.fromInt numDone * batchSizeFrac)))
            val numAdditional =
              Int.max (0, Int.min (desiredSize - numRetry, Seq.length remaining))
            val thisBatchSize = numAdditional + numRetry

            val newcomers = Seq.take remaining numAdditional
            val remaining = Seq.drop remaining numAdditional
            val (winners, losers) =
              batchInsert nn (dsAppend (losers, newcomers))

            val numSucceeded = thisBatchSize - Seq.length losers
            val numDone = numDone + numSucceeded
            val done = winners :: done

            val rate = Real.fromInt numSucceeded / Real.fromInt thisBatchSize
            val pcRate = Real.round (100.0 * rate)

            val _ =
              if not showDelaunayRoundStats then () else
              print ("round " ^ Int.toString numRounds
                    ^ "\tdone " ^ Int.toString numDone
                    ^ "\tremaining " ^ Int.toString totalRemaining
                    ^ "\tdesired " ^ Int.toString desiredSize
                    ^ "\tretrying " ^ Int.toString numRetry
                    ^ "\tfresh " ^ Int.toString numAdditional
                    ^ "\tsuccess-rate " ^ Int.toString pcRate ^ "%\n")

            val (done, (nn, numNextRebuild)) =
              if not (shouldRebuild numNextRebuild numDone) then
                (done, (nn, numNextRebuild))
              else
                let
                  val done = Seq.flatten (Seq.fromList done)
                in
                  ([done], doRebuildNN numNextRebuild done)
                end
          in
            loop (numRounds+1) (done, numDone) (nn, numNextRebuild) losers remaining
          end

      val start: simplex = (2 * Seq.length inputPts, 0)
      val _ = singleInsert start (0, Seq.nth inputPts 0)
      val done = Seq.singleton 0
      val remaining = Seq.drop allVertices 1
      val numDone = 1

      (* val _ = print "inserted first\n" *)

      val nn = buildNN done
      val numNextRebuild = 10

      (* val _ = print ("built initial nn\n") *)

      val (numDone, nn, numNextRebuild, remaining) =
        smallLoop numDone (nn, numNextRebuild) remaining

      (* val _ = print ("finished small loop\n") *)

      val done = [Seq.take allVertices numDone]

      val numRounds =
        loop 0 (done, numDone) (nn, numNextRebuild) (Seq.empty()) remaining

      val t1 = Time.now ()
      val elapsed = Time.toReal (Time.- (t1, t0))

      fun percent x = Real.round (100.0 * (x / elapsed))
      fun rtos x = Real.fmt (StringCvt.FIX (SOME 4)) x
      fun stuff x =
        rtos x ^ "s (" ^ Int.toString (percent x) ^ "%)"

      val _ =
        if not reportTimes then () else
        let
          val _ = print ("----\n")
          (* val _ = print ("find-centers  " ^ stuff (getTimer "find-centers") ^ "\n") *)
          val _ = print ("reserve       " ^ stuff (getTimer "reserve") ^ "\n")
          val _ = print ("rip-and-tent  " ^ stuff (getTimer "rip-and-tent") ^ "\n")
          val _ = print ("split         " ^ stuff (getTimer "split") ^ "\n")
          val _ = print ("nn-rebuild    " ^ stuff (getTimer "nn-rebuild") ^ "\n")
          val _ = print ("other         " ^ stuff (elapsed - timerSum ()) ^ "\n")

          val _ = clearTimers ()
        in
          ()
        end

    in
      (numRounds, mesh)
    end

end
