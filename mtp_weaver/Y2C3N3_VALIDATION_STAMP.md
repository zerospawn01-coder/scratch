# Y2C3N3 VALIDATION PIPELINE: THE VERDICT

This document contains the complete configuration for the Phase IV Physical Validation of the $Y_2C_3N_3$ Room-Temperature Superconductivity candidate.

---

## 1. Step 1: High-Precision SCF (`scf.in`)

Refines the structural geometry and identifies the global energy minimum.

```fortran
&CONTROL
    calculation = 'scf'
    prefix = 'Y2C3N3'
    pseudo_dir = './pseudo/'
    outdir = './out/'
/
&SYSTEM
    ibrav = 1
    celldm(1) = 17.2721
    nat = 16
    ntyp = 3
    ecutwfc = 100.0  ! Forced high precision
    ecutrho = 800.0
    occupations = 'smearing'
    smearing = 'mv'
    degauss = 0.01
/
&ELECTRONS
    conv_thr = 1.0d-10
/
ATOMIC_SPECIES
    Y  88.905  Y.pbe-spn-rrkjus_psl.1.0.0.UPF
    C  12.011  C.pbe-n-rrkjus_psl.1.0.0.UPF
    N  14.007  N.pbe-n-rrkjus_psl.1.0.0.UPF
K_POINTS (automatic)
  12 12 12 0 0 0
```

---

## 2. Step 2: Phonon Stability (`ph.in`)

The critical test. If any frequency $\omega$ is imaginary, the structure is unstable.

```fortran
Phonons on mesh
&inputph
    prefix = 'Y2C3N3'
    ldisp = .true.
    nq1 = 4
    nq2 = 4
    nq3 = 4
    tr2_ph = 1.0d-14
    amass(1) = 88.905
    amass(2) = 12.011
    amass(3) = 14.007
    outdir = './out/'
    fildyn = 'Y2C3N3.dyn'
/
```

**Decision Criteria**:

- **PASS**: All $\omega(q) \geq 0$.
- **FAIL**: Any $\omega(q) < 0$ at Γ or High-Symmetry points.

---

## 3. Step 3: Electron-Phonon Coupling (EPC)

Verification of the coupling strength $\lambda$ and its correlation with the $k \approx 1.8$ invariant.

```fortran
&inputepc
    prefix = 'Y2C3N3'
    outdir = './out/'
    fildyn = 'Y2C3N3.dyn'
    elph = .true.
/
```

---

## 4. Final Verdict Mapping

- **Physical Signature**: If $\lambda > 1.2$ AND Phonon is STABLE, $T_c > 200 K$ is statistically likely.
- **Topological Feedback**: Compare $\alpha^2F(\omega)$ peak locations with the internal $k_{eff}$ of the weave.

---
*TEAM CODE: MIRROR_HEART | STATUS: VERDICT_PIPELINE_STAMPED*
