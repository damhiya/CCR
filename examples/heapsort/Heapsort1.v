Require Import Coqlib.
Require Import ImpPrelude.
Require Import STS.
Require Import Behavior.
Require Import ModSem.
Require Import Skeleton.
Require Import PCM.
Require Import HoareDef.
Require Import ProofMode.
Require Import STB.
Require Import HeapsortHeader.

Set Implicit Arguments.

Section HEAPSORT.
  Context `{Σ : GRA.t}.
         
  Definition create_body : list Z * nat -> itree hEs (list Z) :=
    fun '(base, i) =>
      let nmemb : nat := length base in
      initval <- Ret(Z.to_nat i);;
      base <- ITree.iter(fun '(base, par_i) =>
          if Nat.leb (2*par_i) nmemb
          then (
              child_i <- (if Nat.ltb (2*par_i) nmemb
                         then (child_val0 <- (lookup_1 base (par_i*2))?;;
                               child_val1 <- (lookup_1 base (par_i*2 +1))?;;
                               if Z.ltb child_val0 child_val1
                               then Ret(par_i*2 +1) else Ret(par_i*2)
                              )
                         else Ret (par_i*2));;
              child_val <- (lookup_1 base child_i)?;;
              par_val <- (lookup_1 base par_i)?;;
              if Z.leb child_val par_val
              then Ret (inr base)                                            
              else Ret (inl (swap_1 base child_i par_i, child_i))
            )
          else Ret (inr base)
                       ) (base, initval);;Ret base.

  Definition create_spec : fspec.
  Admitted.
  
  Definition heapify_body : (list Z * Z) -> itree hEs (list Z) :=
    fun '(base, k) =>
    let nmemb : nat := length base in
    '(base, par_i) <- ITree.iter (fun '(base, par_i) =>
      if Nat.leb (par_i * 2) nmemb
      then (
        if Nat.ltb (par_i * 2) nmemb
        then (
          child_l <- (lookup_1 base (par_i * 2))?;;
          child_r <- (lookup_1 base (par_i * 2 + 1))?;;
          let child_i : nat := if Z.ltb child_l child_r then (par_i * 2) else (par_i * 2 + 1) in
          Ret (inl (swap_1 base child_i par_i, child_i))
        )
        else (
          let child_i : nat := par_i * 2 + 1 in
          Ret (inl (swap_1 base child_i par_i, child_i))
        )
      )
      else Ret (inr (base, par_i))
    ) (k :: tail base, 1%nat);;
    '(base, par_i) <- ITree.iter (fun '(base, par_i) =>
      let child_i : nat := par_i in
      let par_i : nat := child_i / 2 in
      if Nat.eqb child_i 1 
      then (
        par <- (lookup_1 base par_i)?;;
        if Z.ltb k par
        then Ret (inr (base, par_i))
        else Ret (inl (swap_1 base child_i par_i, par_i))
      )
      else (
        Ret (inl (swap_1 base child_i par_i, par_i))
      )
    ) (base, par_i);;
    Ret base.

  Definition heapify_spec : fspec.
  Admitted.

  Definition heapsort_body : list Z -> itree hEs (list Z) :=
    fun xs =>
      heap <- ITree.iter (fun '(xs, l) =>
                           if Nat.eqb l 0
                           then Ret (inr xs)
                           else xs' <- trigger (Call "create" (xs, l)↑);;
                                xs'' <- (xs'↓)?;;
                                Ret (inl (xs'', l - 1))
                        )
                        (xs, length xs / 2);;
      ys <- ITree.iter (fun '(heap, ys) =>
                         if Nat.eqb (length heap) 0
                         then Ret (inr ys)
                         else
                           let k := last heap 0%Z in
                           heap_ <- trigger (Call "heapify" (removelast heap, k)↑);;
                           heap <- (heap_↓)?;;
                           Ret (inl (heap, k :: ys))
                      )
                      (heap, []);;
      Ret ys.

  Definition heapsort_spec : fspec.
  Admitted.
  
  Definition HeapsortSbtb : list (gname * fspecbody) :=
    [("create", mk_specbody create_spec (cfunN create_body));
    ("heapify", mk_specbody heapify_spec (cfunN heapify_body));
    ("heapsort", mk_specbody heapsort_spec (cfunN heapsort_body))
    ].

  Definition SHeapsortSem : SModSem.t.
  Admitted.

  Definition SHeapsort : SMod.t.
  Admitted.

  Variable GlobalStb: Sk.t -> gname -> option fspec.
  Definition Heapsort : Mod.t := SMod.to_tgt GlobalStb SHeapsort.

End HEAPSORT.
