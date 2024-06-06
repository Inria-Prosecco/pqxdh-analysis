This repository contains a formal analysis of PQXDH, using ProVerif and CryptoVerif.

It is the artifact for the research paper `Formal verification of the PQXDH Post-Quantum key agreement protocol for end-to-end secure messaging`, by Karthikeyan Bhargavan, Charlie Jacomme, Franziskus Kiefer, and Rolfe Schmidt, published at USENIX Security 2024.

 * `revision1`  contains the analysis of the specification of revision 1, both with ProVerif and CryptoVerif;
 * `revision2` contains the anlysis of the specification of revision 2, both with CryptoVerif and ProVerif;
 * `revision3` contains the anlysis of some attemps at coming up with a revision 3, still both with CryptoVerif and ProVerif;
 * `revision1-WithKyberCR` contains a complement to the analysis of revision 1 in CryptoVerif, by also considering that the implementation uses Kyber, which we prove to satisfy an additional collision resistance property.

## Checking the proof

Each subfolder contain a dedicated README describing the files.

We rely on Proverif 2.04 and CryptoVerif 2.08pl1, easily installed with `opam install proverif` and `opam install cryptoverif` if one has the `opam` ocaml package manager, see the respective webpages otherwise for dedicated installation instructions.

Files may use  preprocessors to enable modeling efficiently several variants of a protocol, a Makefile then gives the appropriate commands to verify the file.

Each file contains it's expected runtime, obtained on a   11th Gen Intel(R) Core(TM) i7-1165G7 @ 2.80GHz, with 31Gb of RAM.

# Background on formal methods

Formal methods in security aim at providing very strong guarantees over the specifications of security protocols. It does so notably by doing computer-aided cryptography, a program is going to either do or verify the security proof.

Two major tools of the domain or ProVerif and CryptoVerif.

CryptoVerif formalizes and partially automates classical cryptographic proof, where we obtain security under the usual notions of IND-CCA, UF-CMA,...

ProVerif works in a more abstract model, the so-called symbolic model, which abstracts away probabilities and cryptographic assumptions. It is very efficient and fully automated, and notably allows considering quickly many compromise scenarios. 

As a summary, CryptoVerif gives guarantees in the classical cryptographic models, but proofs often require manual guidance. ProVerif on its side does not yield the classical cryptographic guarantees, but is highly automated and can help explore many scenarios and notably find attacks.

# Analysis

We summarize below the several steps of the analysis, based on the multiple revisions. The detailed results of each step are in dedicated READMEs in the subfolder.

Overall, our analysis of the revision 1 uncovered several imprecisions within the specification. We in fact identified several theoretical attacks. Importantly, looping with Signal's developers, we saw that the implementation does not suffer from any of those weaknesses. However, it means that a naive implementation of the specification would not meet the classically desired security guarantees for such protocols.

Through discussion with Signal's developers, we identified several changes to the specification so that it better matches the current implementation and so that our theoretical attacks are fixed. This lead to the current revision 2. We also suggested several updates to make the protocol even more resilient on the long term, which are under consideration for a revision 3, but which would imply implementation changes.


## Analysis of revision 1

We made models of this first version in both ProVerif and CryptoVerif. 

Both models are for an unbounded number of agents willing to communicate together, and we allow the compromise of long term identity keys. 

Simply by trying to formally write down the models, we gained several insights:

- F1: PQXDH (as did X3DH) uses the same secret key for X25519 curve computations and XedDSA signatures. No precise security assumption for this joint use case exists. This forced us to make a simplifying assumption in our CryptoVerif model, where we split the identity key is split into two, one for X25519 computations and one for signatures. We noted that this was not explicit in the related work of section 4 of [PQXDH, rev1].
- F2: No explicit assumption for the AEAD was mentioned in [PQXDH, rev1], while the secrecy of exchanged messages of course depends on the post-quantum security of the AEAD.

Then, when trying to come up with the proof in CryptoVerif, two suspicious appeared:

- F3: we could not make the proof without making the assumption that encodeEC is always distinct from encodeKEM, as otherwise, SPK and PQPK can be confused.
- F4: it did not look possible to prove authentication of the KEM public key, that is, even if two parties compute the same key, we could not prove that they agree on the KEM public key which was used.

Going to ProVerif, we were in fact able to confirm that there are theoretical attacks on the protocol:
- F3': an attacker can send a SPK instead of the PQPK to an initiator. If the length of the KEM public keys and curve public keys are equal, the protocol would proceed. The initiator then tries to compute an encapsulation, but using a curve element. The classical security guarantees of the KEM are only over honestly generated public keys of the KEM, we are thus in a situation where we have no security guarantees, and the shared secret can be weak and guessable by the attacker. 
- F3'': it is in fact also possible for an attack to send a PQPK instead of a SPK, maybe making multiple curve based computation go to a weak secret.
- F4: we demonstrated that if we use a secure IND-CCA public key encryption to build an IND-CCA KEM, an attacker can in fact make two parties compute the same key but both believe to have used a distinct public key. The main issue here is that from the responder point of view, we do not have session independance: compromising the PQPK of one session can break the security of another independent session using an unrelated PQPK. This in fact means that the compromise of a single responder's PQPK implies the compromise of all its other present and futur PQPK.


Generalizing on F3, we also had a last comment:
- F5: we observed that there is no way for the initiator to know whether it is using a last resort PQPK or a one time one.

Interestingly, F3'' in fact illustrates how by adding an extra component to a secure protocol, we may in fact lower the guarantees of the protocol.
F4 is delicate to handle, as some KEM designers precisely state that "Application designers are encouraged to assume solely
the standard IND-CCA2 property" [MCR]

Importantly, from the practical point of view, those two issues are thwarted in the implementation:
- each public key encoding is prefixed by a one byte identifier corresponding to the algorithm, and no confusion is possible;
- Kyber in facts ties the shared secret to the KEM public key.

Based on those 5 feedbacks, several fixes/improvements were proposed:
- S1: clarify the gap in existing security proofs, and that there is still the need for a deeper study of the X25519 and XedDSA interactions;
- S2: clarify the security assumptions over the AEAD, which is in fact a parameter of the protocol;
- S3: clarify in the spec that the encodings must be disjoint;
- S4: clarify that IND-CCA in general does not tie the shared secret to the public key, but mention that Kyber does things correctly
- S4': add the KEM public key either in the AD
- S4'': add the key derivation hash computations.
- S5: add byte identifiers separating last resort and one time keys.


## Analysis of revision 2

S1,2,3 and 4, not requiring changes to the implementation, were integrated inside revision 2, as well as S4' in the form of a recommendation. S4' and S5 were kept for later updates.

The most notable change in term of security in the models was to add the kem public key in the AD, and remove some ProVerif threat model now explicitly forbidden by the spec (notably the public key signature confusions).

In this new version, we were able to obtain all most desired security properties:

* In CryptoVerif, we prove over revision 2 that under the gapDH assumption for the X25519 curve, the UF-CMA assumption over EdDSA (with disjoint keys), the ROM for the hash function and the IND-CPA+INT-CTXT assumption for the AEAD, we have secrecy and authentication of any completed key exchange. Moreover, just IND-CCA for the KEM, PRF for the hash function and IND-CPA+INT-CTXT is enough to ensure the future secrecy of keys as long as the signature was still UF-CMA when the key exchange took place.

* In ProVerif, we prove in the symbolic model both authentication and secrecy, enumerating precisely the necessary condition so that the attacker can break the properties. Our security properties notably imply forward secrecy, resistance to harvest now decrypt later attacks, resistance to key compromise impersonation, and session independence.

The main limitation of our analysis are:

* the assumption in CryptoVerif that the identity key and signature key are in fact two distinct keys;
* we don't have all possible compromise we would want in the CryptoVerif model, so the computational analysis could be improved in this direction;
* putting the public key in the AD does not exactly mimic the behaviour of what Kyber does by including the public key in the shared secret.

## Proposals for revision 3

Exchanging with Signal's developers, we are currently investigating several changes to the specification that would imply changes to the implementation.

We provide here a model where:
- P1: the F prefix in the hash function is removed. It does not seem to be needed anymore, compared to X3DH, as the info avoid any confusion.
- P2: we directly put more information inside the KDF, at least the KEM pubic key, and are considering putting even more elements of the transcript.
- P3: we add public key type identifiers (last resort or one time) in the signatures of the PQPK.


Based on the new models, the observations are that:
- P1 does not indeed change the security results, so it is a good simplification
- P2 is interesting, it in fact simplifies the proof, by making sure even without the AEAD so two parties compute the same key only when they use the same PQPK.
- P3 does not enable us to verify any new security properties, as an untrusted server can always only send the last resort PQPK (but at least, now the initiator is aware of it). Improved monitoring of the server still requires some work.

Adding even more elements to the transcript, such as the other DH public keys, while good practice, does not always bring any obvious new security property. This also needs further exploring.
Some remarks on this:
- adding the IK_A and IK_B in the transcript also enables us to remove them from the AEAD AD, and as for the PQPK, make sure that two parties derive the same key only when they agree on the IKs used. This one is a bit more important, as for the moment, we need the AEAD AD to ensure that no small sub group equivalent public key of IK_A or IK_B was used. 
- adding the SPK, OPK and EK_A seems more optional. Currently, the parties only agree on those values modulo the small sub group elements. Yet, it does not have any clear security impact.

Overall, including information directly inside the KDF rather than in the AD makes the cryptographic proof simpler, and notably less dependent on the security of the AEAD.

## Revision 1 with Kyber

To justify the security of the existing implementation, we pushed further the analysis regarding the fact that " Kyber in facts ties the shared secret to the KEM public key."

We developped a dedicated collision resistance notion on KEMs that capture this intuition, proved it for Kyber, and proved that PQXDH under this additional assumption does ensure the authentication o the PQPSK, thus thwarting F4.


## Acknowledgements

This analysis is joint work between INRIA and Cryspen, and was carried
out by Karthikean Barghavan, Charlie Jacomme and Franziskus Kiefer. It
was inspired by a previous CryptoVerif model for TextSecure (a variant
of X3DH) made by Bruno Blanchet.  Theophile Wallez gave precious
insights w.r.t. to the encodings used in the specification.

We thank Rolfe Schmidt and Ehren Kret for the fruitful interactions
and many insights into the specification and Signal's implementation.


# References


[PQXDH]: https://signal.org/docs/specifications/pqxdh/, The PQXDH Key Agreement Protocol

[MCR]: https://classic.mceliece.org/mceliece-rationale-20221023.pdf, Classic McEliece: conservative code-based cryptography: design rationale
