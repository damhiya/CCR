Require Import Coqlib.
Require Import Skeleton.
Require Import PCM.
Require Import HoareDef.
Require Import ProofMode.
Require Import STB.
Require Import Any.
Require Import ModSem.
Require Import ModSemE.
Require Import ClightDmMem1.
From compcertip Require Export Ctypes Values AST Memdata Integers.

Set Implicit Arguments.

Section PROP.

  Context `{@GRA.inG pointstoRA Σ}.
  Context `{@GRA.inG allocatedRA Σ}.
  Context `{@GRA.inG blocksizeRA Σ}.
  Context `{@GRA.inG blockaddressRA Σ}.

  Definition vlist_add (x: val) (l : list val) (at_tail: val) : list val :=
    if Val.eq at_tail Vzero then x :: l else snoc l x.

  Definition vlist_delete (l: list val) (from_tail: val) (default: val) : val * list val :=
    if Val.eq from_tail Vzero then (hd default l, tl l)
    else (last l default, removelast l).

  Definition check_inbound (l: list val) (from_tail: val) (index: val) : option nat :=
    match index with
    | Vint i =>
      if negb (Coqlib.zle 0 (Int.unsigned i) && Coqlib.zlt (Int.unsigned i) (Z.of_nat (List.length l)))
      then None
      else if Val.eq Vzero from_tail then Some (Z.to_nat (Int.unsigned i))
           else Some (List.length l - Z.to_nat (Int.unsigned i))
    | Vlong i => 
      if negb (Coqlib.zle 0 (Int64.unsigned i) && Coqlib.zlt (Int64.unsigned i) (Z.of_nat (List.length l)))
      then None
      else if Val.eq Vzero from_tail then Some (Z.to_nat (Int64.unsigned i))
           else Some (List.length l - Z.to_nat (Int64.unsigned i))
    | _ => None
    end.

     (* is_xorlist represents the figure below    *)
     (*    ll_h                              ll_t *)
     (*     |                                 |   *)
     (*     v                                 v   *)
     (* xs  - - - - - - - - - - - - - - - - - -   *)

  Fixpoint frag_xorlist (q: Qp) (p_hd_prev p_hd p_tl p_tl_next: val) (xs : list val) {struct xs} : iProp :=
    match xs with
    | [] => ⌜p_hd_prev = p_tl /\ p_hd = p_tl_next⌝
    | Vlong a :: xs' =>
      if Val.eq Vnullptr p_hd_prev
      then
        ∃ p_next m_hd m_next i_next ofs_next tg_next,
          p_hd ↦m_hd#q≻ (encode_val Mint64 (Vlong a) ++ encode_val Mptr (Vptrofs (Ptrofs.repr i_next)))
          ** (if Z.eqb i_next 0 then ⌜p_next = Vnullptr⌝
             else (p_next ⊨m_next# ofs_next
                  ** live_ q # (m_next, tg_next) 
                  ** p_next (≃_ m_next) i_next))
          ** frag_xorlist q p_hd p_next p_tl p_tl_next xs'
      else
        ∃ p_next m_prev m_hd m_next i_prev i_key ofs_next tg_next,
          p_hd ↦m_hd#q≻ (encode_val Mint64 (Vlong a) ++ encode_val Mptr (Vptrofs (Ptrofs.repr i_key)))
          ** p_hd_prev (≃_ m_prev) i_prev
          ** (if Z.eqb (Z.lxor i_prev i_key) 0 then ⌜p_next = Vnullptr⌝
             else (p_next ⊨m_next# ofs_next)
                  ** live_ q # (m_next, tg_next) 
                  ** p_next (≃_ m_next) (Z.lxor i_prev i_key))
          ** frag_xorlist q p_hd p_next p_tl p_tl_next xs'
    | _ => False
    end%I.

  Definition full_xorlist q p_hd p_tl xs : iProp := 
    frag_xorlist q Vnullptr p_hd p_tl Vnullptr xs.

  Lemma real_pointer_notnull'
      vaddr m ofs
    :
      vaddr ⊨m# ofs ⊢ ⌜Coqlib.proj_sumbool (Val.eq Vnullptr vaddr) = false⌝.
  Proof.
  Admitted.

  Lemma points_to_notnull
      vaddr m q mvs
    :
      vaddr ↦m#q≻ mvs ⊢ ⌜Coqlib.proj_sumbool (Val.eq Vnullptr vaddr) = false⌝.
  Proof.
  Admitted.


  Example xorlist_example1 p1 p2 p3 m1 m2 m3 i1 i2 i3 ofs3 tg3 ofs2 tg2:
  p1 ↦m1#1≻ (encode_val Mint64 (Vlong Int64.one) ++ encode_val Mint64 (Vlong (Int64.repr i2)))
  ** p1 (≃_ m1) i1
  ** p2 ↦m2#1≻ (encode_val Mint64 (Vlong Int64.one) ++ encode_val Mint64 (Vptrofs (Ptrofs.repr (Z.lxor i1 i3))))
  ** p2 ⊨m2# ofs2
  ** live_ 1# (m2, tg2)
  ** p2 (≃_ m2) i2
  ** p3 ↦m3#1≻ (encode_val Mint64 (Vlong Int64.one) ++ encode_val Mint64 (Vlong (Int64.repr i2)))
  ** p3 ⊨m3# ofs3
  ** live_ 1# (m3, tg3)
  ** p3 (≃_ m3) i3
  ⊢ full_xorlist 1 p1 p3 [Vlong Int64.one;Vlong Int64.one;Vlong Int64.one].
  Proof.
  Admitted.
    (* iIntros "[[[[[[[i j] h] b] c] d] e] f]".
    unfold full_xorlist. ss. des_ifs_safe.
    iExists _,_,_,_,_,_. unfold Vptrofs in *.
    destruct Archi.ptr64 eqn: X; clarify.
    ss. unfold Mptr in *.
    destruct Archi.ptr64 eqn: X'; clarify.
    unfold Ptrofs.to_int64 in *.
    iPoseProof (points_to_notnull with "i") as "%".
    iPoseProof (captured_pointer_notnull with "c") as "%".
    iPoseProof (capture_dup with "c") as "[c c']".
    iSplitL "i b c".
    { instantiate (1:= i2). 
      rewrite (Int64.unsigned_repr (Ptrofs.unsigned _)).
      2:{ change Int64.max_unsigned with Ptrofs.max_unsigned.
          apply Ptrofs.unsigned_range_2. }
      iFrame. 
      instantiate (2:=p2).
      destruct (i2 =? 0)%Z eqn:E.
      { apply Z.eqb_eq in E. clarify. }
      iFrame. }
    iPoseProof (captured_pointer_notnull with "f") as "%".
    destruct (Val.eq _ _); ss; clarify.
    iExists _,_,_,_,_,_,_,_.
    iPoseProof (points_to_notnull with "h") as "%".
    iSplitL "h e f j".
    { instantiate (1:=(Z.lxor i1 i3)).
      instantiate (3:=p3).
      rewrite (Int64.unsigned_repr (Ptrofs.unsigned _)).
      2:{ change Int64.max_unsigned with Ptrofs.max_unsigned.
          apply Ptrofs.unsigned_range_2. }
      rewrite <- Z.lxor_assoc. rewrite Z.lxor_nilpotent.
      rewrite Z.lxor_0_l.
      destruct (i3 =? 0)%Z eqn: E'.
      { apply Z.eqb_eq in E'. clarify. }
      iFrame. }
    destruct (Val.eq _ _); ss; clarify.
    iExists _,_,_,_,_,_,_,_.
    instantiate (2:=i2).
    rewrite (Int64.unsigned_repr (Ptrofs.unsigned _)).
    2:{ change Int64.max_unsigned with Ptrofs.max_unsigned.
        apply Ptrofs.unsigned_range_2. }
    iFrame. iSplit; et. rewrite Z.lxor_nilpotent. ss.
  Unshelve. all: et.
  Qed. *)

  Example xorlist_example2 p2 m2:
  p2 ↦m2#1≻ (encode_val Mint64 (Vlong Int64.one) ++ encode_val Mint64 (Vptrofs Ptrofs.zero))
  ⊢ full_xorlist 1 p2 p2 [Vlong Int64.one].
  Proof.
    iIntros "d".
    unfold full_xorlist. ss.
    destruct (Val.eq Vnullptr _); clarify.
    iExists _,_,_,_,_,_. iFrame. ss.
  Unshelve.
  - exact m2.
  - exact 0.
  - exact Local.
  Qed.
    
  Lemma split_xorlist q p_hd_prev p_hd p_tl p_tl_next xs0 xs1
    : frag_xorlist q p_hd_prev p_hd p_tl p_tl_next (xs0 ++ xs1)
      ⊢ ∃ mid mid_next, frag_xorlist q p_hd_prev p_hd mid mid_next xs0 ** frag_xorlist q mid mid_next p_tl p_tl_next xs1.
  Proof.
    (* revert q p_hd_prev p_hd p_tl p_tl_next xs1.
    induction xs0; i; ss.
    - iIntros "A". iExists _,_. iSplit; et.
    - iIntros "A". des_ifs.
      + iDestruct "A" as (p_next m_hd m_next i_next ofs_next tg_next) "[PTO NXT]".
        iDestruct "PTO" as "[PTO RES]". clarify.
        iPoseProof (IHxs0 with "NXT") as (mid mid_next) "[NXT0 NXT1]".
        des_ifs.
        * apply Z.eqb_eq in Heq. clarify.
          iDestruct "RES" as "%". clarify.
          iExists _,_. iFrame.
          iExists _,_,_,_,_,_. iFrame. ss.
        * iDestruct "RES" as "[NXT_ALIVE NXT_CAP]". clarify.
          iExists _,_. iFrame.
          iExists _,_,_,_,_,_. iFrame. rewrite Heq.
          iFrame.
      + iDestruct "A" as (p_next m_prev m_hd m_next i_prev i_key ofs_next tg_next) "[PTO NXT]".
        iDestruct "PTO" as "[[PTO CAP_PREV] RES]".
        iPoseProof (IHxs0 with "NXT") as (mid mid_next) "[NXT0 NXT1]".
        des_ifs.
        * iDestruct "RES" as "%". apply Z.eqb_eq in Heq. clarify.
          iExists _,_. iFrame.
          iExists _,_,_,_,_,_,_,_. iFrame. rewrite Heq.
          ss.
        * iDestruct "RES" as "[NXT_ALIVE NXT_CAP]".
          iExists _,_. iFrame.
          iExists _,_,_,_,_,_,_,_. iFrame. rewrite Heq.
          iFrame.
  Unshelve. all: et.
  Qed. *)
  Admitted.

  Lemma concat_xorlist q p_hd_prev p_hd p_tl p_tl_next mid mid_next xs0 xs1
    : frag_xorlist q p_hd_prev p_hd mid mid_next xs0 ** frag_xorlist q mid mid_next p_tl p_tl_next xs1
      ⊢ frag_xorlist q p_hd_prev p_hd p_tl p_tl_next (xs0 ++ xs1).
  Proof.
    (* revert q p_hd_prev p_hd p_tl p_tl_next mid mid_next xs1.
    induction xs0; i; ss.
    - iIntros "[% A]". des. clarify.
    - iIntros "A". des_ifs; try solve [iDestruct "A" as "[% A]"; clarify].
      + iDestruct "A" as "[PTO NXT1]". 
        iDestruct "PTO" as (p_next m_hd m_next i_next ofs_next tg_next) "[[PTO RES] NXT0]".
        clarify. iCombine "NXT0 NXT1" as "NXT".
        iPoseProof (IHxs0 with "NXT") as "NXT".
        des_ifs.
        * apply Z.eqb_eq in Heq. clarify.
          iDestruct "RES" as "%". clarify.
          iExists _,_,_,_,_,_. iFrame. ss.
        * iDestruct "RES" as "[NXT_ALIVE NXT_CAP]".
          iExists _,_,_,_,_,_. iFrame. rewrite Heq.
          iFrame.
      + iDestruct "A" as "[PTO NXT1]". 
        iDestruct "PTO" as (p_next m_prev m_hd m_next i_prev i_key ofs_next tg_next) "[[[PTO CAP_PREV] RES] NXT]".
        clarify. iCombine "NXT NXT1" as "NXT".
        iPoseProof (IHxs0 with "NXT") as "NXT".
        des_ifs.
        * iDestruct "RES" as "%". apply Z.eqb_eq in Heq. clarify.
          iExists _,_,_,_,_,_,_,_. iFrame. rewrite Heq.
          ss.
        * iDestruct "RES" as "[NXT_ALIVE NXT_CAP]".
          iExists _,_,_,_,_,_,_,_. iFrame. rewrite Heq.
          iFrame.
  Unshelve. all: et.
  Qed. *)
  Admitted.

End PROP.

Section SPEC.

  Context `{@GRA.inG pointstoRA Σ}.
  Context `{@GRA.inG allocatedRA Σ}.
  Context `{@GRA.inG blocksizeRA Σ}.
  Context `{@GRA.inG blockaddressRA Σ}.

  (* The function only requires resource needed by capture *)
  (* Definition encrypt_spec : fspec :=
    (mk_simple
      (fun '(left_ptr, right_ptr, b1, b2, sz1, sz2, tag1, tag2, q1, q2) => (
            (ord_pure 1%nat),
            (fun varg => ∃ ofs1 ofs2 opt1 opt2, ⌜varg = [left_ptr; right_ptr]↑⌝
                          ** left_ptr ⊸ (b1, ofs1)
                          ** b1 ↱q1# (sz1, tag1, opt1)
                          ** right_ptr ⊸ (b2, ofs2)
                          ** b2 ↱q2# (sz2, tag2, opt2)),
            (fun vret => ∃ i1 i2, ⌜vret = (Vptrofs (Ptrofs.repr (Z.lxor i1 i2)))↑⌝
                          ** b1 ↱q1# (sz1, tag1, Some i1)
                          ** b2 ↱q2# (sz2, tag2, Some i2))

    )))%I. *)
  Definition encrypt_hoare1 : _ -> ord * (Any.t -> iProp) * (Any.t -> iProp) :=
      fun '(left_ptr, right_ptr, m_l, m_r, tg_l, tg_r, q_l, q_r) => (
            (ord_pure 1%nat),
            (fun varg => ∃ ofs_l ofs_r, ⌜varg = [left_ptr; right_ptr]↑⌝
                         ** left_ptr ⊨m_l# ofs_l
                         ** right_ptr ⊨m_r# ofs_r
                         ** live_ q_l# (m_l, tg_l)
                         ** live_ q_r# (m_r, tg_r)),
            (fun vret => ∃ i_l i_r, ⌜vret = (Vptrofs (Ptrofs.repr (Z.lxor i_l i_r)))↑⌝
                         ** left_ptr (≃_ m_l) i_l
                         ** right_ptr (≃_ m_r) i_r
                         ** live_ q_l# (m_l, tg_l)
                         ** live_ q_r# (m_r, tg_r)))%I.

  Definition encrypt_hoare2 : _ -> ord * (Any.t -> iProp) * (Any.t -> iProp) :=
      fun '(left_ptr, m_l, tg_l, q_l) => (
            (ord_pure 1%nat),
            (fun varg => ∃ ofs_l, ⌜varg = [left_ptr; Vnullptr]↑⌝
                         ** left_ptr ⊨m_l# ofs_l
                         ** live_ q_l# (m_l, tg_l)),
            (fun vret => ∃ i_l, ⌜vret = (Vptrofs (Ptrofs.repr i_l))↑⌝
                         ** left_ptr (≃_ m_l) i_l
                         ** live_ q_l# (m_l, tg_l)))%I.

  Definition encrypt_hoare3 : _ -> ord * (Any.t -> iProp) * (Any.t -> iProp) :=
      fun '(right_ptr, m_r, tg_r, q_r) => (
            (ord_pure 1%nat),
            (fun varg => ∃ ofs_r, ⌜varg = [Vnullptr; right_ptr]↑⌝
                         ** right_ptr ⊨m_r# ofs_r
                         ** live_ q_r# (m_r, tg_r)),
            (fun vret => ∃ i_r, ⌜vret = (Vptrofs (Ptrofs.repr i_r))↑⌝
                         ** right_ptr (≃_ m_r) i_r
                         ** live_ q_r# (m_r, tg_r)))%I.
  
  Definition encrypt_spec :=
    mk_simple (
      encrypt_hoare1
      @ encrypt_hoare2
      @ encrypt_hoare3
    ).

  Definition decrypt_hoare1 : _ -> ord * (Any.t -> iProp) * (Any.t -> iProp) :=
      fun '(i_key, ptr, m, q, tg) => (
        (ord_pure 1%nat),
        (fun varg => ∃ key ofs, ⌜varg = [key; ptr]↑ /\ key = Vptrofs i_key⌝
                     ** ptr ⊨m# ofs
                     ** live_ q# (m, tg)),
        (fun vret => ∃ i_ptr, ⌜vret = (Vptrofs (Ptrofs.xor i_key (Ptrofs.repr i_ptr)))↑⌝
                     ** ptr (≃_m) i_ptr
                     ** live_ q# (m, tg)))%I.
                     
  Definition decrypt_hoare2 : _ -> ord * (Any.t -> iProp) * (Any.t -> iProp) :=
      fun '(i_key) => (
        (ord_pure 1%nat),
        (fun varg => ∃ key, ⌜varg = [key; Vnullptr]↑ /\ key = Vptrofs i_key⌝),
        (fun vret => ⌜vret = (Vptrofs i_key)↑⌝))%I.
  
  Definition decrypt_spec : fspec :=
    mk_simple (
      decrypt_hoare1
      @ decrypt_hoare2
    ).

  (* {hd_handler |-> hd  /\ tl_handler |-> tl /\ is_xorlist hd tl xs}
     void add(node** hd_handler, node** tl_handler, long item, bool at_tail)
     {r. if hd = null
         then exists new_node, hd_handler |-> new_node /\ tl_handler |-> new_node /\ is_xorlist new_node new_node [item]
         else if at_tail = false
              then exists new_hd, hd_handler |-> new_hd /\ tl_handler |-> tl /\ is_xorlist new_hd tl (item :: xs)
              else exists new_tl, hd_handler |-> hd /\ tl_handler |-> new_tl /\ is_xorlist hd new_tl (xs ++ [item])
     } *)

  Definition add_spec : fspec :=
    (mk_simple
      (fun '(hd_handler, tl_handler, m_h, m_t, item, at_tail, xs) => (
        (ord_pure 2%nat),
        (fun varg => ∃ hd_old tl_old,
                     ⌜varg = [hd_handler; tl_handler; Vlong item; Vint at_tail]↑⌝
                     ** hd_handler ↦m_h#1≻ encode_val Mptr hd_old
                     ** tl_handler ↦m_t#1≻ encode_val Mptr tl_old
                     ** full_xorlist 1 hd_old tl_old xs),
        (fun vret => ∃ hd_new tl_new,
                     ⌜vret = Vundef↑⌝
                     ** hd_handler ↦m_h#1≻ encode_val Mptr hd_new
                     ** tl_handler ↦m_t#1≻ encode_val Mptr tl_new
                     ** full_xorlist 1 hd_new tl_new (vlist_add (Vlong item) xs (Vint at_tail)))
    )))%I.

  (* {hd_handler |-> hd  /\ tl_handler |-> tl /\ is_xorlist hd tl xs}
     long delete(node** hd_handler, node** tl_handler, bool from_tail)
     {r. if hd = null
         then r = 0 /\ hd_handler |-> hd /\ tl_handler |-> tl /\ is_xorlist hd tl []
         else if from_tail = false
              then r = last xs /\ exists new_hd, hd_handler |-> new_hd /\ tl_handler |-> tl /\ is_xorlist new_hd tl (removelast xs)
              else r = hd xs /\ exists new_tl, hd_handler |-> hd /\ tl_handler |-> new_tl /\ is_xorlist hd new_tl (tl xs)
     } *)
  Definition delete_spec : fspec :=
    (mk_simple
      (fun '(hd_handler, tl_handler, m_h, m_t, from_tail, xs) => (
        (ord_pure 2%nat),
        (fun varg => ∃ hd_old tl_old, ⌜varg = [hd_handler; tl_handler; Vint from_tail]↑⌝
                     ** hd_handler ↦m_h#1≻ encode_val Mptr hd_old
                     ** tl_handler ↦m_t#1≻ encode_val Mptr tl_old
                     ** full_xorlist 1 hd_old tl_old xs),
        (fun vret => let '(item, xs') := vlist_delete xs (Vint from_tail) (Vlong Int64.zero) in
                     ∃ hd_new tl_new, ⌜vret = item↑⌝
                     ** hd_handler ↦m_h#1≻ encode_val Mptr hd_new
                     ** tl_handler ↦m_t#1≻ encode_val Mptr tl_new
                     ** full_xorlist 1 hd_new tl_new xs')
    )))%I.

  Definition search_spec : fspec :=
    (mk_simple
      (fun '(hd_handler, tl_handler, from_tail, index, idx, xs, m_h, m_t, q, q_h, q_t) => (
        (ord_pure 2%nat),
        (fun varg => ∃ hd tl, ⌜varg = [hd_handler; tl_handler; Vint from_tail; Vlong index]↑
                     /\ check_inbound xs (Vint from_tail) (Vlong index) = Some idx⌝
                     ** hd_handler ↦m_h#q_h≻ encode_val Mptr hd
                     ** tl_handler ↦m_t#q_t≻ encode_val Mptr tl
                     ** full_xorlist q hd tl xs),
        (fun vret => ∃ hd tl mid mid_prev, ⌜vret = mid↑⌝
                     ** hd_handler ↦m_h#q_h≻ encode_val Mptr hd
                     ** tl_handler ↦m_t#q_t≻ encode_val Mptr tl
                     ** frag_xorlist q mid_prev mid tl Vnullptr (drop idx xs)
                     ** frag_xorlist q Vnullptr hd mid_prev mid (firstn idx xs))
    )))%I.

  (* sealed *)
  Definition xorStb : list (gname * fspec).
    eapply (Seal.sealing "stb").
    apply [("encrypt", encrypt_spec);
           ("decrypt", decrypt_spec);
           ("add", add_spec);
           ("delete", delete_spec);
           ("search", search_spec)
           ].
  Defined.

End SPEC.

Require Import xorlist0.

Section SMOD.

  Context `{@GRA.inG pointstoRA Σ}.
  Context `{@GRA.inG allocatedRA Σ}.
  Context `{@GRA.inG blocksizeRA Σ}.
  Context `{@GRA.inG blockaddressRA Σ}.

  Definition xorSbtb: list (gname * fspecbody) :=
    [("encrypt",  mk_pure encrypt_spec);
     ("decrypt",  mk_pure decrypt_spec);
     ("add",  mk_pure add_spec);
     ("delete",  mk_pure delete_spec);
     ("search",  mk_pure search_spec)
     ].
  
  Definition SxorSem : SModSem.t := {|
    SModSem.fnsems := xorSbtb;
    SModSem.mn := "xorlist";
    SModSem.initial_mr := ε;
    SModSem.initial_st := tt↑;
  |}.
  
  Definition Sxor : SMod.t := {|
    SMod.get_modsem := fun _ => SxorSem;
    SMod.sk := xorlist0.xor.(Mod.sk);
  |}.
  
  Definition xor stb : Mod.t := (SMod.to_tgt stb) Sxor.
  
End SMOD.