Require Import Coqlib.
Require Import Universe.
Require Import STS.
Require Import Behavior.
Require Import ModSem.
Require Import Skeleton.
Require Import PCM.
Require Import HoareDef.
Require Import TODOYJ.

Generalizable Variables E R A B C X Y Σ.

Set Implicit Arguments.



(*** TODO: move to TODOYJ ***)
Definition resum_ktr A E F `{E -< F}: ktree E A ~> ktree F A := fun _ ktr a => interp (fun _ e => trigger e) (ktr a).



Definition putint_parg: list val -> option val :=
  fun varg =>
    match varg with
    | [v] => Some v
    | _ => None
    end
.


(* Parameter inF: list val -> itree eventE val. *)
(* Parameter putintF: list val -> itree eventE val. *)

(* Extract Constant inF => "___MINKI_DOTHIS___?????????". *)
(* Extract Constant putintF => "___MINKI_DOTHIS___?????????". *)


Definition getintF:  list val -> itree eventE val :=
  fun _ => trigger (Syscall "scanf" []).

Definition putintF: list val -> itree eventE val :=
  fun varg =>
    `v: val <- (putint_parg varg)?;;
    trigger (Syscall "printf" varg);;
    Ret Vundef
.


Section PROOF.

  Context `{Σ: GRA.t}.

  Definition ClientSem: ModSemL.t := {|
    ModSemL.fnsems := [("getint", cfun (resum_ktr getintF)); ("putint", cfun (resum_ktr putintF))];
    ModSemL.initial_mrs := [("Client", (ε, tt↑))];
  |}
  .

  Definition Client: Mod.t := {|
    Mod.get_modsem := fun _ => ClientSem;
    Mod.sk := Sk.unit;
  |}
  .

End PROOF.
