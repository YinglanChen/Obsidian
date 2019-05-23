{-# OPTIONS --allow-unsolved-metas #-}

module ConsistencyForSimpleExprs where

  open import Silica
  open import HeapPropertiesDefs
  open import HeapLemmasForSplitting
  
  import Context

  open TypeEnvContext
  open import Data.Nat
  open import Relation.Nullary using (¬_; Dec; yes; no)
  open import Data.Empty
  import Relation.Binary.PropositionalEquality as Eq

  simpleExprsPreserveConsistency : ∀ {Σ Δ Δ'' T}
                                 → {se : SimpleExpr}
                                 → Σ & Δ ok
                                 → Δ ⊢ simpleExpr se ⦂ T ⊣ Δ''
                                 → ∃[ Δ' ] (Σ & Δ' ok)

  simpleExprsPreserveConsistency {Σ} {.(_ ,ₗ l ⦂ _)}
    consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
    (locTy {Γ} {Δ₀}  {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl@(unownedSplit _ _ _ _)) =
    ⟨ Δ' , ok {Σ} Δ' voidLookup' boolLookup' objLookup' refConsistency' ⟩
    where
      splT = splitType spl
      o = proj₁ (objLookup l t₁ Z)
      Δ'' = Δ₀ ,ₗ l ⦂ (SplitType.t₃ splT) -- This is the result of checking e.
      Δ' = Δ'' ,ₒ o ⦂ (SplitType.t₂ splT) -- This is the typing context in which we need to typecheck e'.
 
      --Δ = Δ₀ ,ₗ l ⦂ (SplitType.t₁ splT)
      -- Show that if you look up l in the new context, you get the same type as before.
      voidLookup' : (∀ (l' : IndirectRef)
                    → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Void
                    → (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ voidVal)))
      voidLookup' l' l'InΔ' with l' Data.Nat.≟ l
      voidLookup' l' (Context.S l'NeqL l'VoidType) | yes eq = ⊥-elim (l'NeqL eq)
      voidLookup' l' l'InΔ' | no nEq = voidLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
  
      boolLookup' : (∀ (l' : IndirectRef)
                     → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Boolean
                    → ∃[ b ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ boolVal b)))
      boolLookup' l' l'InΔ' with l' Data.Nat.≟ l
      boolLookup' l' (Context.S l'NeqL l'BoolType) | yes eq = ⊥-elim (l'NeqL eq)
      boolLookup' l' l'InΔ' | no nEq = boolLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
      
      objLookup' : (l' : IndirectRef) → (T : Tc)
                   → ((StaticEnv.locEnv Δ') ∋ l' ⦂ (contractType T)
                   → ∃[ o ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ objVal o × (o ObjectRefContext.∈dom (RuntimeEnv.μ Σ))))
      objLookup' l' _ l'InΔ' with l' Data.Nat.≟ l
      objLookup' l' _ (Context.S l'NeqL l'ObjType) | yes eq = ⊥-elim (l'NeqL eq)
      objLookup' l' t l'InΔ'@(Z {a = contractType t₃}) | yes eq = objLookup l' t₁ Z
      objLookup' l' t l'InΔ' | no nEq = objLookup l' t (S nEq (irrelevantReductionsOK l'InΔ' nEq))

      l⦂oInρ : RuntimeEnv.ρ Σ IndirectRefContext.∋ l ⦂ objVal o
      l⦂oInρ = proj₁ ( proj₂  (objLookup l t₁ Z))
      lookupUnique : objVal o ≡ objVal ( proj₁ (objLookup l t₁ Z))
      lookupUnique = IndirectRefContext.contextLookupUnique {RuntimeEnv.ρ Σ} l⦂oInρ (proj₁ (proj₂ (objLookup l t₁ Z))) -- ?
      oLookupUnique = objValInjectiveContrapositive lookupUnique

      -- Show that all location-based aliases from the previous environment are compatible with the new alias.
      -- Note that Σ is unchanged, so we use Σ instead of defining a separate Σ'.
      refConsistency' : (o' : ObjectRef) → o' ObjectRefContext.∈dom (RuntimeEnv.μ Σ) → ReferenceConsistency Σ Δ' o'
      refConsistency' o' o'Inμ =
        let
          origRefConsistency = refConsistencyFunc o' o'Inμ
          origConnected =  referencesConsistentImpliesConnectivity origRefConsistency
          newConnected = splitReplacementOK {Γ} {Σ} {Δ₀} {o} {o'} {l} {t₁} {t₂} {SplitType.t₁ splT} {SplitType.t₂ splT} {SplitType.t₃ splT}
                                            refl refl consis oLookupUnique (proj₁ origConnected) (proj₂ origConnected) spl
        in 
          referencesConsistent {_} {_} {o'} newConnected

  simpleExprsPreserveConsistency {Σ} {.(_ ,ₗ l ⦂ _)}
    consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
    (locTy {Γ} {Δ₀}  {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl@(shared-shared-shared _)) =
    ⟨ Δ' , ok {Σ} Δ' voidLookup' boolLookup' objLookup' refConsistency' ⟩
    where
      splT = splitType spl
      o = proj₁ (objLookup l t₁ Z)
      Δ'' = Δ₀ ,ₗ l ⦂ (SplitType.t₃ splT) -- This is the result of checking e.
      Δ' = Δ'' ,ₒ o ⦂ (SplitType.t₂ splT) -- This is the typing context in which we need to typecheck e'.
 
      --Δ = Δ₀ ,ₗ l ⦂ (SplitType.t₁ splT)
      -- Show that if you look up l in the new context, you get the same type as before.
      voidLookup' : (∀ (l' : IndirectRef)
                    → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Void
                    → (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ voidVal)))
      voidLookup' l' l'InΔ' with l' Data.Nat.≟ l
      voidLookup' l' (Context.S l'NeqL l'VoidType) | yes eq = ⊥-elim (l'NeqL eq)
      voidLookup' l' l'InΔ' | no nEq = voidLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
  
      boolLookup' : (∀ (l' : IndirectRef)
                     → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Boolean
                    → ∃[ b ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ boolVal b)))
      boolLookup' l' l'InΔ' with l' Data.Nat.≟ l
      boolLookup' l' (Context.S l'NeqL l'BoolType) | yes eq = ⊥-elim (l'NeqL eq)
      boolLookup' l' l'InΔ' | no nEq = boolLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
      
      objLookup' : (l' : IndirectRef) → (T : Tc)
                   → ((StaticEnv.locEnv Δ') ∋ l' ⦂ (contractType T)
                   → ∃[ o ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ objVal o × (o ObjectRefContext.∈dom (RuntimeEnv.μ Σ))))
      objLookup' l' _ l'InΔ' with l' Data.Nat.≟ l
      objLookup' l' _ (Context.S l'NeqL l'ObjType) | yes eq = ⊥-elim (l'NeqL eq)
      objLookup' l' t l'InΔ'@(Z {a = contractType t₃}) | yes eq = objLookup l' t₁ Z
      objLookup' l' t l'InΔ' | no nEq = objLookup l' t (S nEq (irrelevantReductionsOK l'InΔ' nEq))

      l⦂oInρ : RuntimeEnv.ρ Σ IndirectRefContext.∋ l ⦂ objVal o
      l⦂oInρ = proj₁ ( proj₂  (objLookup l t₁ Z))
      lookupUnique : objVal o ≡ objVal ( proj₁ (objLookup l t₁ Z))
      lookupUnique = IndirectRefContext.contextLookupUnique {RuntimeEnv.ρ Σ} l⦂oInρ (proj₁ (proj₂ (objLookup l t₁ Z))) -- ?
      oLookupUnique = objValInjectiveContrapositive lookupUnique

      -- Show that all location-based aliases from the previous environment are compatible with the new alias.
      -- Note that Σ is unchanged, so we use Σ instead of defining a separate Σ'.
      refConsistency' : (o' : ObjectRef) → o' ObjectRefContext.∈dom (RuntimeEnv.μ Σ) → ReferenceConsistency Σ Δ' o'
      refConsistency' o' o'Inμ =
        let
          origRefConsistency = refConsistencyFunc o' o'Inμ
          origConnected =  referencesConsistentImpliesConnectivity origRefConsistency
          newConnected = splitReplacementOK {Γ} {Σ} {Δ₀} {o} {o'} {l} {t₁} {t₂} {SplitType.t₁ splT} {SplitType.t₂ splT} {SplitType.t₃ splT}
                                            refl refl consis oLookupUnique (proj₁ origConnected) (proj₂ origConnected) spl
        in 
          referencesConsistent {_} {_} {o'} newConnected

  simpleExprsPreserveConsistency {Σ} {.(_ ,ₗ l ⦂ _)}
    consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
    (locTy {Γ} {Δ₀}  {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl@(owned-shared _)) =
    ⟨ Δ' , ok {Σ} Δ' voidLookup' boolLookup' objLookup' refConsistency' ⟩
    where
      splT = splitType spl
      o = proj₁ (objLookup l t₁ Z)
      Δ'' = Δ₀ ,ₗ l ⦂ (SplitType.t₃ splT) -- This is the result of checking e.
      Δ' = Δ'' ,ₒ o ⦂ (SplitType.t₂ splT) -- This is the typing context in which we need to typecheck e'.
 
      --Δ = Δ₀ ,ₗ l ⦂ (SplitType.t₁ splT)
      -- Show that if you look up l in the new context, you get the same type as before.
      voidLookup' : (∀ (l' : IndirectRef)
                    → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Void
                    → (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ voidVal)))
      voidLookup' l' l'InΔ' with l' Data.Nat.≟ l
      voidLookup' l' (Context.S l'NeqL l'VoidType) | yes eq = ⊥-elim (l'NeqL eq)
      voidLookup' l' l'InΔ' | no nEq = voidLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
  
      boolLookup' : (∀ (l' : IndirectRef)
                     → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Boolean
                    → ∃[ b ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ boolVal b)))
      boolLookup' l' l'InΔ' with l' Data.Nat.≟ l
      boolLookup' l' (Context.S l'NeqL l'BoolType) | yes eq = ⊥-elim (l'NeqL eq)
      boolLookup' l' l'InΔ' | no nEq = boolLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
      
      objLookup' : (l' : IndirectRef) → (T : Tc)
                   → ((StaticEnv.locEnv Δ') ∋ l' ⦂ (contractType T)
                   → ∃[ o ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ objVal o × (o ObjectRefContext.∈dom (RuntimeEnv.μ Σ))))
      objLookup' l' _ l'InΔ' with l' Data.Nat.≟ l
      objLookup' l' _ (Context.S l'NeqL l'ObjType) | yes eq = ⊥-elim (l'NeqL eq)
      objLookup' l' t l'InΔ'@(Z {a = contractType t₃}) | yes eq = objLookup l' t₁ Z
      objLookup' l' t l'InΔ' | no nEq = objLookup l' t (S nEq (irrelevantReductionsOK l'InΔ' nEq))

      l⦂oInρ : RuntimeEnv.ρ Σ IndirectRefContext.∋ l ⦂ objVal o
      l⦂oInρ = proj₁ ( proj₂  (objLookup l t₁ Z))
      lookupUnique : objVal o ≡ objVal ( proj₁ (objLookup l t₁ Z))
      lookupUnique = IndirectRefContext.contextLookupUnique {RuntimeEnv.ρ Σ} l⦂oInρ (proj₁ (proj₂ (objLookup l t₁ Z))) -- ?
      oLookupUnique = objValInjectiveContrapositive lookupUnique

      -- Show that all location-based aliases from the previous environment are compatible with the new alias.
      -- Note that Σ is unchanged, so we use Σ instead of defining a separate Σ'.
      refConsistency' : (o' : ObjectRef) → o' ObjectRefContext.∈dom (RuntimeEnv.μ Σ) → ReferenceConsistency Σ Δ' o'
      refConsistency' o' o'Inμ =
        let
          origRefConsistency = refConsistencyFunc o' o'Inμ
          origConnected =  referencesConsistentImpliesConnectivity origRefConsistency
          newConnected = splitReplacementOK {Γ} {Σ} {Δ₀} {o} {o'} {l} {t₁} {t₂} {SplitType.t₁ splT} {SplitType.t₂ splT} {SplitType.t₃ splT}
                                            refl refl consis oLookupUnique (proj₁ origConnected) (proj₂ origConnected) spl
        in 
          referencesConsistent {_} {_} {o'} newConnected
  simpleExprsPreserveConsistency {Σ} {.(_ ,ₗ l ⦂ _)}
    consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
    (locTy {Γ} {Δ₀}  {T₁ = contractType t₁} {T₂ = contractType t₂} {T₃ = contractType t₃} l spl@(states-shared _)) =
    ⟨ Δ' , ok {Σ} Δ' voidLookup' boolLookup' objLookup' refConsistency' ⟩
    where
      splT = splitType spl
      o = proj₁ (objLookup l t₁ Z)
      Δ'' = Δ₀ ,ₗ l ⦂ (SplitType.t₃ splT) -- This is the result of checking e.
      Δ' = Δ'' ,ₒ o ⦂ (SplitType.t₂ splT) -- This is the typing context in which we need to typecheck e'.
 
      --Δ = Δ₀ ,ₗ l ⦂ (SplitType.t₁ splT)
      -- Show that if you look up l in the new context, you get the same type as before.
      voidLookup' : (∀ (l' : IndirectRef)
                    → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Void
                    → (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ voidVal)))
      voidLookup' l' l'InΔ' with l' Data.Nat.≟ l
      voidLookup' l' (Context.S l'NeqL l'VoidType) | yes eq = ⊥-elim (l'NeqL eq)
      voidLookup' l' l'InΔ' | no nEq = voidLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
  
      boolLookup' : (∀ (l' : IndirectRef)
                     → ((StaticEnv.locEnv Δ') ∋ l' ⦂ base Boolean
                    → ∃[ b ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ boolVal b)))
      boolLookup' l' l'InΔ' with l' Data.Nat.≟ l
      boolLookup' l' (Context.S l'NeqL l'BoolType) | yes eq = ⊥-elim (l'NeqL eq)
      boolLookup' l' l'InΔ' | no nEq = boolLookup l' (S nEq (irrelevantReductionsOK l'InΔ' nEq))
      
      objLookup' : (l' : IndirectRef) → (T : Tc)
                   → ((StaticEnv.locEnv Δ') ∋ l' ⦂ (contractType T)
                   → ∃[ o ] (RuntimeEnv.ρ Σ IndirectRefContext.∋ l' ⦂ objVal o × (o ObjectRefContext.∈dom (RuntimeEnv.μ Σ))))
      objLookup' l' _ l'InΔ' with l' Data.Nat.≟ l
      objLookup' l' _ (Context.S l'NeqL l'ObjType) | yes eq = ⊥-elim (l'NeqL eq)
      objLookup' l' t l'InΔ'@(Z {a = contractType t₃}) | yes eq = objLookup l' t₁ Z
      objLookup' l' t l'InΔ' | no nEq = objLookup l' t (S nEq (irrelevantReductionsOK l'InΔ' nEq))

      l⦂oInρ : RuntimeEnv.ρ Σ IndirectRefContext.∋ l ⦂ objVal o
      l⦂oInρ = proj₁ ( proj₂  (objLookup l t₁ Z))
      lookupUnique : objVal o ≡ objVal ( proj₁ (objLookup l t₁ Z))
      lookupUnique = IndirectRefContext.contextLookupUnique {RuntimeEnv.ρ Σ} l⦂oInρ (proj₁ (proj₂ (objLookup l t₁ Z)))
      oLookupUnique = objValInjectiveContrapositive lookupUnique

      -- Show that all location-based aliases from the previous environment are compatible with the new alias.
      -- Note that Σ is unchanged, so we use Σ instead of defining a separate Σ'.
      refConsistency' : (o' : ObjectRef) → o' ObjectRefContext.∈dom (RuntimeEnv.μ Σ) → ReferenceConsistency Σ Δ' o'
      refConsistency' o' o'Inμ =
        let
          origRefConsistency = refConsistencyFunc o' o'Inμ
          origConnected =  referencesConsistentImpliesConnectivity origRefConsistency
          newConnected = splitReplacementOK {Γ} {Σ} {Δ₀} {o} {o'} {l} {t₁} {t₂} {SplitType.t₁ splT} {SplitType.t₂ splT} {SplitType.t₃ splT}
                                            refl refl consis oLookupUnique (proj₁ origConnected) (proj₂ origConnected) spl
        in 
          referencesConsistent {_} {_} {o'} newConnected
  simpleExprsPreserveConsistency {Σ} {.(_ ,ₗ l ⦂ _)}
    consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
    (locTy {Γ} {Δ₀} l voidSplit) = 
      ⟨ Δ , consis ⟩
    
  simpleExprsPreserveConsistency {Σ} {.(_ ,ₗ l ⦂ _)}
    consis@(ok Δ voidLookup boolLookup objLookup refConsistencyFunc)
    (locTy {Γ} {Δ₀} l booleanSplit) = 
      ⟨ Δ , consis ⟩
    


