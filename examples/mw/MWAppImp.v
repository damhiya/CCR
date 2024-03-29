Require Import Coqlib.
Require Import ITreelib.
Require Import ImpPrelude.
Require Import STS.
Require Import Behavior.
Require Import ModSem.
Require Import Skeleton.
Require Import PCM.
Require Import Imp.
Require Import ImpNotations.

Set Implicit Arguments.



Section PROOF.
  Context `{Σ: GRA.t}.

  Import ImpNotations.
  Local Open Scope expr_scope.
  Local Open Scope stmt_scope.

  Definition initF :=
    mk_function
      []
      ["init"; "initv"]
      ("init" =#& "initialized" ;# "initv" =#* "init" ;#
       if# "initv"
       then# @! "print" [(- 1)%Z : expr]
       else# @ "MW.put" [0%Z: expr; 42%Z: expr] ;# "init" *=# 1%Z
       fi#
      )
  .

  Definition runF :=
    mk_function
      []
      ["init"; "initv"; "v"]
      ("init" =#& "initialized" ;# "initv" =#* "init" ;#
       if# ("initv" =? (0%Z))
       then# @! "print" [(- 1)%Z : expr]
       else# "v" =@ "MW.get" [0%Z: expr] ;# @! "print" ["v": expr]
       fi#
      )
  .

  Definition Appprog: program :=
    mk_program
      "App"
      []
      [("MW.put", 2); ("MW.get", 1)]
      [("initialized", 0%Z)]
      [("App.init", initF); ("App.run", runF)]
  .

  Definition AppSem ge: ModSem.t := ImpMod.modsem Appprog ge.
  Definition App: Mod.t := ImpMod.get_mod Appprog.

End PROOF.
