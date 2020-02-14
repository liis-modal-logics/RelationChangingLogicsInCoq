From Mtac2 Require Import Mtac2.
From Coq.Sets Require Import Constructive_sets.
From Coq.Relations Require Import Relations.
From Coq.Lists Require Import List.
From RCLIC Require Import utilities.

Require Import Classical.

Require Import ssreflect.

(* This removes the requirement to have all goals with the same
   hierarchy. For instance, without it, one must write:

   have a_hypothesis : some_prop.
   - the proof of some_prop.
   - the proof continues here.

   which is less convenient than

   have a_hypothesis : some_prop.
   - the proof of some_prop.
   the proof continues here.
*)
Set Bullet Behavior "None".


Import Tactics.
Import Sets.

(* General definitions *)

(* The set of propositional variables. *)
Inductive prop : Set :=
  p : nat -> prop.

(* Valuation function *)
Definition valuation (W: Set) : Type := set (prop * W).

Structure model := {
  m_states :> Set;
  m_rel : relation m_states;
  m_val: valuation m_states
}.

Structure pointed_model := {
  pm_model :> model;
  pm_point : pm_model
}.

Structure state_model (W: Set) := {
  st_point: W;
  st_rel: relation W;
  st_val: valuation W
}.

Notation "⟨ a , b , c ⟩" :=
  {| st_point := a; st_val := c; st_rel := b |}.

Notation "⟪ a , b , c ⟫, m" :=
  {| pm_model := {| m_states := a; m_rel := b; m_val := c |};
     pm_point := m |} (at level 0).

Arguments st_point {W}.
Arguments st_rel {W}.
Arguments st_val {W}.

Definition to_pm {W} (st: state_model W) :=
  ⟪ _, st.(st_rel), st.(st_val) ⟫, (st.(st_point)).

Coercion to_pm: state_model >-> pointed_model.

Definition to_st 𝔐 := ⟨𝔐.(pm_point), 𝔐.(m_rel), 𝔐.(m_val)⟩.

Coercion to_st: pointed_model >-> state_model.

Lemma to_st_val (𝔐: pointed_model) : m_val 𝔐 = st_val 𝔐.
  by [].
Qed.

Lemma to_st_point (𝔐: pointed_model) : pm_point 𝔐 = st_point 𝔐.
  by [].
Qed.

Lemma to_st_to_pm {W} (st: state_model W): to_st (to_pm st) = st.
  by case: st.
Defined.

Section InvarianceTheorem.

(* Syntax *)
Variable Dyn : Set.
Variable d : Dyn.

Inductive form : Set :=
  | Atom    : prop -> form
  | Bottom  : form
  | If      : form -> form -> form
  | DynDiam : form -> form.

Coercion Atom : prop >-> form.

(* Basic notation *)
Notation "⊥'" := Bottom.

Notation "p ->' q" := (If p q)
                     (at level 90, right associativity).

Notation "⃟ ϕ" := (DynDiam ϕ)
                        (at level 65, right associativity).

(* Syntactic sugar *)
Definition Not (ϕ : form) : form := ϕ ->' ⊥'.

Notation "~' p" := (Not p)
                   (at level 70, right associativity).

Definition Top : form := ~'⊥'.

Notation "⊤'" := Top.

Definition And (ϕ ψ : form) : form := ~' (ϕ ->' ~'ψ).

Notation "p /\' q" := (And p q)
                     (at level 80, right associativity).

Definition Or (ϕ ψ : form) : form := ~'ϕ ->' ψ.

Notation "p \/' q" := (Or p q)
                     (at level 85, right associativity).

Definition Iif (ϕ ψ : form) : form := (ϕ ->' ψ) /\' (ψ ->' ϕ).

Notation "p <->' q" := (Iif p q)
                     (at level 95, right associativity).

Definition DynBox (ϕ : form) : form := ~'⃟ ~'ϕ.

Notation "⃞ ϕ" := (DynBox ϕ)
                        (at level 65, right associativity).

(* Semantics *)

Definition muf : Type := forall (W : Set),
  state_model W -> set (state_model W).

Variable F : Dyn -> muf.

Reserved Notation "p |= ϕ" (at level 30).

Fixpoint satisfies (𝔐: pointed_model) (ϕ : form) : Prop :=
  match ϕ with
  | Atom a => (a, 𝔐.(pm_point)) ∈ 𝔐.(m_val)
  | Bottom => False
  | ϕ1 ->' ϕ2 => (𝔐 |= ϕ1) -> (𝔐 |= ϕ2)
  | ⃟ϕ =>
    let fw := F d 𝔐.(m_states) in
    exists p', p' ∈ fw 𝔐  /\  p' |= ϕ
  end
where "p |= ϕ" := (satisfies p ϕ).

Theorem sat_classic : forall st ϕ, st |= ϕ \/ st |= ~' ϕ.
Proof. by move=>*; apply: classic. Qed.

Definition equivalent (𝔐 𝔐': pointed_model) :=
  forall (ϕ: form), (𝔐 |= ϕ) <-> (𝔐' |= ϕ).

Notation "m ≡ m'" := (equivalent m m') (at level 0).

(* Semantic Definitions *)
Section Bisimulation.

Context {W W' : Set}.

Definition state_model_relation : Type :=
  state_model W -> state_model W' -> Prop.

Context (Z : state_model_relation).

Definition atomic_harmony : Prop :=
  forall p p', Z p p' -> forall pr: prop,
      (pr, p.(st_point)) ∈ p.(st_val) <-> (pr, p'.(st_point)) ∈ p'.(st_val).

Definition f_zig (f : muf) : Prop :=
  forall p q p', Z p p' ->
    q ∈ f W p ->
    (exists q', q' ∈ f W' p' /\ Z q q').

Definition f_zag (f : muf) : Prop :=
  forall p q' p', Z p p' ->
    q' ∈ f W' p' ->
    (exists q, q ∈ f W p /\ Z q q').

Definition bisimulation : Prop :=
  atomic_harmony /\
  f_zig (F d) /\ f_zag (F d).

End Bisimulation.

Definition bisimilar (𝔐 𝔐': pointed_model) : Prop :=
  exists Z, bisimulation Z /\ Z 𝔐 𝔐'.

Notation "𝔐 ⇆ 𝔐'" := (bisimilar 𝔐 𝔐') (at level 30).


Arguments state_model_relation : clear implicits.

Section Getters.

Context {W W' : Set}.
Context {Z: state_model_relation W W'}.
Context (bis: bisimulation Z).

Definition get_AH : atomic_harmony Z.
  move: bis =>[HA _].
  exact: HA.
Defined.

Definition get_Zig : f_zig Z (F d).
  move: bis =>[_ [H _]].
  exact: H.
Defined.

Definition get_Zag : f_zag Z (F d).
  move: bis =>[_ [_ H]].
  exact: H.
Defined.

End Getters.


Theorem InvarianceUnderBisimulation :
  forall 𝔐 𝔐' : pointed_model,
  𝔐 ⇆ 𝔐' -> 𝔐 ≡ 𝔐'.

Proof.
  move=> 𝔐 𝔐' bis ϕ.
  move: 𝔐 𝔐' bis.
  elim: ϕ => [prop | | ϕ IHϕ ψ IHψ | ϕ IH] /=
             𝔐 𝔐'.
  + move=> [Z [bis HZ]].
    rewrite !to_st_val !to_st_point.
    by apply ((get_AH bis) ?? HZ).
 
  + by [].

  + move=>bis.
    split; move=> HIf Hsat;
      apply (IHψ ?? bis);
      apply HIf;
      by apply (IHϕ ?? bis).
 
  + move=> [Z [bis HZ]]. 
    split.
 
    - move=> [q [HqinfW Hsatq]].
      apply ((get_Zig bis) ?? HZ) in HqinfW
        as [q' [Hq'infW' HZqq']].
      exists q'.
      split; first by [].
      apply (IH q) ; last by [].
      exists Z.
      by rewrite !to_st_to_pm.
      
    - move=> [q' [Hq'infW' Hsatq']].
      apply ((get_Zag bis) ?? HZ) in Hq'infW'
          as [q [HqinfW HZqq']].
      exists q.
      split; first by [].
      eapply (IH q); last by eassumption.
      exists Z.
      by rewrite !to_st_to_pm.
Qed.

Section Satisfability.

Variable 𝔐 : model.
Variable 𝔖 : set (state_model 𝔐.(m_states)).
Variable Σ : set form.
Variable ϕ : form.

Definition sat :=
  exists st : state_model 𝔐.(m_states),
    st ∈ 𝔖 /\ (forall ϕ : form, ϕ ∈ Σ -> st |= ϕ).

Definition f_sat := forall Δ: finset Σ,
  exists st : state_model 𝔐, st ∈ 𝔖 /\
  Forall (fun ϕ : form=> st |= ϕ) Δ.

End Satisfability.

Arguments sat {_}.
Arguments f_sat {_}.

Section Saturation.

Variable 𝔐 : model.
Definition fw := F d 𝔐.

Definition image_iden : set (state_model 𝔐) :=
  fun st => st_rel st = m_rel 𝔐 /\ st_val st = m_val 𝔐.

Definition image_fw : set (state_model 𝔐) := 
  fun st => exists st': state_model 𝔐, st ∈ fw st'.

Definition image := image_iden ∪ image_fw.

Definition saturation :=
  forall (Σ: set form) (st: state_model 𝔐),
    st ∈ image -> let 𝔖 := fw st in
                  f_sat 𝔖 Σ -> sat 𝔖 Σ.

End Saturation.

Section HennesyMilner.

Variable 𝔐 : pointed_model.
Variable 𝔐' : pointed_model.

Hypothesis M_sat : saturation 𝔐.
Hypothesis M'_sat : saturation 𝔐'.

Let f__W := F d 𝔐.
Let f__W' := F d 𝔐'.

Definition equiv_in_image st st' :=
    st ∈ image 𝔐 /\
    st' ∈ image 𝔐' /\
    st ≡ st'.

Notation "a ↭ b" := (equiv_in_image a b) (at level 40).

Definition big_and Δ := fold_right And Top Δ.

Notation "'⋀' Δ" := (big_and Δ) (at level 0).

Lemma sat_fold_forall m Δ: 
  Forall (fun ϕ : form => m |= ϕ) Δ <-> m |= ⋀Δ.
Proof.
  elim: Δ; first by simpl; tauto.
  move=>ϕ Δ /= ->.
  tauto.
Qed.


Lemma equiv_in_image_bisimulation : bisimulation equiv_in_image.
Proof.
  split_ands.
  - move=> s s' s_s' p.
    case: s_s' =>[s_img [s'_img seqs']].
    split; move=> ?.
    + have sat : s |= p by assumption.
      by move/seqs': sat.
    + have sat : s' |= p by assumption.
      by move/seqs': sat.

  - move=>[s S X] [t T Y] [s' S' X'] /=.
    move=>[imgS [imgS' SeqS']] tTYinsSX.
    set Σ : set form := (fun ϕ=> ⟨ t , T , Y ⟩ |= ϕ).

    have sat_big_and :
      forall Δ : finset Σ, ⟨t, T, Y⟩ |= ⋀Δ.
    + case.
      elim=>/= [ |ϕ Δ IH]; first by [].
      case=>Hϕ. move/IH=> HΔ.
      by apply.

    have sat_diamond_big_and :
      forall Δ : finset Σ, ⟨s, S, X⟩ |= ⃟⋀Δ.
    + move=>Δ.
      exists ⟨t, T, Y⟩.
      split; first by [].
      by apply: sat_big_and.

    have sat_diamond_big_and' :
      forall Δ : finset Σ, ⟨s', S', X'⟩ |= ⃟⋀Δ
        by move=>Δ; apply/SeqS'.

    have sat_next_big_and' :
      forall Δ : finset Σ, exists st', st' ∈ f__W' ⟨s', S', X'⟩ /\ st' |= ⋀Δ.
    + move=>Δ.
      move: (sat_diamond_big_and' Δ) => [st' [IH1 IH2]].
      by exists st'.
      
    pose 𝔖' : set (state_model _) :=
      fun st' => st' ∈ f__W' ⟨ s', S', X' ⟩ /\
              exists Δ : finset Σ, st' |= ⋀Δ.

    have 𝔖'_fsat : f_sat 𝔖' Σ.
    + move=>Δ.
      move: (sat_next_big_and' Δ)=>[st' [infw' satΔ]].
      exists st'.
      split_ands.
      * by [].
      * by exists Δ.
      * by apply sat_fold_forall.

    have fw'_fsat : f_sat (f__W' ⟨ s', S', X' ⟩) Σ.
    + move=>Δ.
      move: (𝔖'_fsat Δ)=>[st' [ [ ? ?] ?]].
      by exists st'.

    have fw'_sat : sat (f__W' ⟨ s', S', X' ⟩) Σ
      by apply: M'_sat.

    case: fw'_sat=>st' [inS H].
    exists st'.
    split; first by [].
    have tTY_img : ⟨ t, T, Y ⟩ ∈ image 𝔐.
    + apply: Union_intror.
      eexists.
      eassumption.

    have st_img : st' ∈ image 𝔐'.
    + apply: Union_intror.
      eexists.
      eassumption.

    split_ands; try by [].
    move=>ϕ.
    split.
    + move=>Ht.
      apply: H.
      by apply: Ht.
             
    + case: (sat_classic  ⟨ t, T, Y ⟩ ϕ); first by [].
      fold (Σ (~' ϕ)).
      move/H => sat_notϕ sat_ϕ.
      apply sat_notϕ in sat_ϕ.
      contradiction.

  - move=>[s S X] [t' T' Y'] [s' S' X'] /=.
    move=>[imgS [imgS' SeqS']] t'T'Y'insSX.
    set Σ : set form := (fun ϕ=> ⟨ t' , T' , Y' ⟩ |= ϕ).

    have sat_big_and' :
      forall Δ : finset Σ, ⟨t', T', Y'⟩ |= ⋀Δ.
    + case.
      elim=> /= [ |ϕ Δ IH]; first by [].
      case=>Hϕ. move/IH=> HΔ.
      by apply.

    have sat_diamond_big_and' :
      forall Δ : finset Σ, ⟨s', S', X'⟩ |= ⃟⋀Δ.
    + move=>Δ.
      exists ⟨t', T', Y'⟩.
      split; first by [].
      by apply: sat_big_and'.

    have sat_diamond_big_and :
      forall Δ : finset Σ, ⟨s, S, X⟩ |= ⃟⋀Δ
        by move=>Δ; apply/SeqS'.

    have sat_next_big_and :
      forall Δ : finset Σ, exists st, st ∈ f__W ⟨s, S, X⟩ /\ st |= ⋀Δ.
    + move=>Δ.
      move: (sat_diamond_big_and Δ)=> /= [st [IH1 IH2]].
      by exists st.

    pose 𝔖 : set (state_model _) :=
      fun st => st ∈ f__W ⟨ s, S, X ⟩ /\
              exists Δ : finset Σ, st |= ⋀Δ.

    have 𝔖_fsat : f_sat 𝔖 Σ.
    + move=>Δ.
      move: (sat_next_big_and Δ)=>[st [infw satΔ]].
      exists st.
      split_ands.
      * by [].
      * by exists Δ.
      * by apply sat_fold_forall.

    have fw_fsat : f_sat (f__W ⟨ s, S, X ⟩) Σ.
    + move=>Δ.
      move: (𝔖_fsat Δ)=>[st [ [ ? ?] ?]].
      by exists st.

    have fw_sat : sat (f__W ⟨ s, S, X ⟩) Σ
      by apply: M_sat.

    case: fw_sat=>st [inS H].
    exists st.
    split; first by [].
    have tTY_img : ⟨ t', T', Y' ⟩ ∈ image 𝔐'.
    + apply: Union_intror.
      eexists.
      eassumption.

    have st_img : st ∈ image 𝔐.
    + apply: Union_intror.
      eexists.
      eassumption.

    split_ands; try by [].
    move=>ϕ.
    split.
    + case: (sat_classic ⟨ t', T', Y' ⟩ ϕ); first by [].
      fold (Σ (~' ϕ)).
      move/H => sat_notϕ sat_ϕ.
      apply sat_notϕ in sat_ϕ.
      contradiction.

    + move=>Ht.
      apply: H.
      by apply: Ht.
Qed.

Corollary HennesyMilner : 𝔐 ≡ 𝔐' -> 𝔐 ⇆ 𝔐'.
Proof.
  move=> Heq.
  unfold bisimilar.
  exists equiv_in_image.
  split; first by apply equiv_in_image_bisimulation.
  split_ands.
  - apply: Union_introl.
    rewrite /Ensembles.In /image_iden; tauto.
  - apply: Union_introl.
    rewrite /Ensembles.In /image_iden; tauto.
  - move: 𝔐 𝔐' Heq => [ [W R V] /= w] [ [W' R' V'] /= w'].
    by apply.
Qed.

End HennesyMilner.

End InvarianceTheorem.


(* Local Variables: *)
(* company-coq-local-symbols: ( ) *)
(* End: *)
