Require Import Coqlib.
Require Import ITreelib.
Require Import ImpPrelude.
Require Import STS.
Require Import Behavior.
Require Import ModSem.
Require Import Skeleton.
Require Import PCM.
Require Import HoareDef STB.
Require Import MWHeader.
Require Import Mem1.

Set Implicit Arguments.



Section PROOF.

  Notation pget := (p0 <- trigger PGet;; p0 <- p0↓?;; Ret p0) (only parsing). (*** NOTE THAT IT IS UB CASTING ***)
  Notation pput p0 := (trigger (PPut p0↑)) (only parsing).

  Variant cls: Type := uninit | opt | normal.

  Global Program Instance cls_Dec: Dec cls. Next Obligation. decide equality. Defined.

  Record local_state: Type := mk_lst {
    lst_cls: Z -> cls;
    lst_opt: Z -> val;
    lst_map: val;
    (* lst_wf: forall k, (is_some (lst_opt k)) -> (is_some (lst_dom k)) *)
  }
  .

  Let Es := (hAPCE +' Es).

  Notation upd_cls f := (lst0 <- pget;; pput (mk_lst (f lst0.(lst_cls)) lst0.(lst_opt) lst0.(lst_map))).
  Notation upd_opt f := (lst0 <- pget;; pput (mk_lst lst0.(lst_cls) (f lst0.(lst_opt)) lst0.(lst_map))).
  Notation upd_map f := (lst0 <- pget;; pput (mk_lst lst0.(lst_cls) lst0.(lst_opt) (f lst0.(lst_map)))).

  Definition loopF: list val -> itree Es val :=
    fun varg =>
      _ <- (pargs [] varg)?;;
      `_: val <- ccallU "App.run" ([]: list val);;
      `_: val <- ccallU "MW.loop" ([]: list val);;
      Ret Vundef
  .

  Definition mainF: list val -> itree Es val :=
    fun varg =>
      _ <- (pargs [] varg)?;;;
      `map: val <- ccallU "Map.new" ([]: list val);;
      pput (mk_lst (fun _ => uninit) (fun _ => Vundef) map);;;
      `_: val <- ccallU "App.init" ([]: list val);;
      `_: val <- ccallU "MW.loop" ([]: list val);;
      Ret Vundef
  .

  Definition putF: list val -> itree Es val :=
    fun varg =>
      '(k, v) <- (pargs [Tint; Tuntyped] varg)?;;
      assume(intrange_64 k);;;
      lst0 <- pget;;
      (if dec (lst0.(lst_cls) k) uninit
       then b <- trigger (Choose _);; let class := (if (b: bool) then opt else normal) in upd_cls (fun cls => set k class cls);;; Ret tt
       else Ret tt);;;
      lst0 <- pget;;
      (if dec (lst0.(lst_cls) k) opt
       then _ <- upd_opt (fun opt => set k v opt);;; Ret tt
       else `_: val <- ccallU "Map.update" ([lst0.(lst_map); Vint k; v]);; Ret tt);;;
      syscallU "print" [k];;;
      Ret Vundef
  .

  Definition getF: list val -> itree Es val :=
    fun varg =>
      k <- (pargs [Tint] varg)?;;
      assume(intrange_64 k);;;
      lst0 <- pget;;
      assume(lst0.(lst_cls) k <> uninit);;;
      v <- (if dec (lst0.(lst_cls) k) opt
            then ;;; Ret (lst0.(lst_opt) k)
            else ccallU "Map.access" ([lst0.(lst_map); Vint k]));;
      syscallU "print" [k];;;
      Ret v
  .

  Context `{Σ: GRA.t}.
  Context `{@GRA.inG spRA Σ}.

  Definition MWsbtb: list (string * fspecbody) :=
    [("main", mk_specbody fspec_mw1 (cfunU mainF));
    ("MW.loop", mk_specbody fspec_mw1 (cfunU loopF));
    ("MW.put", mk_specbody fspec_mw1 (cfunU putF));
    ("MW.get", mk_specbody fspec_mw1 (cfunU getF))
    ].

  Definition SMWSem: SModSem.t := {|
    SModSem.fnsems := MWsbtb;
    SModSem.mn := "MW";
    SModSem.initial_mr := (GRA.embed sp_black);
    SModSem.initial_st := tt↑;
  |}
  .

  Definition SMW: SMod.t := {|
    SMod.get_modsem := fun _ => SMWSem;
    SMod.sk := [("MW.loop", Sk.Gfun); ("MW.put", Sk.Gfun); ("MW.get", Sk.Gfun);
               ("gv0", Sk.Gvar 0); ("gv1", Sk.Gvar 0)];
  |}
  .

  Context `{@GRA.inG memRA Σ}.

  Definition MW: Mod.t := (SMod.to_tgt (fun _ => to_stb MW1Stb) SMW).

End PROOF.
