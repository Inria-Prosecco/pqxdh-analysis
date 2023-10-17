This folder contains a model of the PQXDH protocol, as specified in:

[PQXDH] : https://signal.org/docs/specifications/pqxdh/
	  The PQXDH Key Agreement Protocol
	  Revision 1, 2023-05-24, Last Updated: 2023-09-20


# Model description

The file models:
- an arbitrary number of clients (devices) communicating with each other
- each device uploads Curve and KEM keys to a server which is fully untrusted (modelled as a public channel)
- each connection consists of one message from the initiator to the responder (with no follow-up messages)
- each connection can optionnaly use an OPK
- PQPK can always be reused, this is a worst case scenario where they are all last resort
- the identifiers of the prefkeys do not need to verify any particular assumption

## Limitations

The main limitation of the model is that we split the identity key IK into two keys, one DH key and one signing key. In practice, a single DH IK is used both for X25519 operations and XEdDSA signatures. To be completely precise, one would thus need to analyze the protocol under the gapDH assumption while also assuming that the attacker can obtain DH computations through the oracle signature. Such a proof does not exist in the litterature (also, while Ed25519 is proved, XEdDSA is not, which is a small gap). For instance, [8] proves the security of X3DH assuming gapDH, but also assuming that in fact all signed prekeys are pre-authenticated, and simply drop the signature question. Our model is thus more fine-grained. 

*Feedback 1*: Remark that in this respect, the related work introduced in section 4 of the PQXDH spec is a bit imprecise, as it only says "was formally studied in [8] and proven secure under the Gap Diffie-Hellman assumption (GDH)[9].". The need for a full proof of PQXDH (and X3DH) under a joint gapDH and EUF-CMA security over X25519 and XEdDSA is still present. 

A second limitation here is that we cannot prove anything w.r.t. to whether an untrusted server only gives the last resort PQPK, or never gives any OPK. This echoes the security consideration in 4.9.

# Threat models

In term of key compromise, we allow compromise of long term identity keys IK.

In addition, the file includes two distinct set of threat models, one assuming the security of DH, and the other one assuming the security of the KEM. This notably correspond to either considering that the attacker is classical or post-quantum.

## Secure DH threat model

In the classical setting, this file assumes that
 * the KDF function is a ROM
 * the signature Sig is EUF-CMA
 * the X25519 curve is gapDH
 * the final AEAD is IND-CPA and IND-CTXT



## Secure KEM threat model
 
In the PQ setting, this file assumes that:
 * the KDF function is a post-quantum PRF w.r.t. to the kem secret position
 * the EUF-CMA is a post-quantum EUF-CMA signature
 * the KEM is post-quantum IND-CCA
 * the final AEAD is post-quanum IND-CPA and IND-CTXT
 
 Remark here that it looks like we assume that the signature Sig is post-quantum secure. Yet, as we allow compromise of signing keys, we can also see it as, the scheme is secure as long as the attacker does not try to compromise it using its quantum power, the only assumption being that we are able to know when the attacker does so. 
 

# Security Results

In both cases, we remarked that it is impossible to do the proof without making an additional assumption compared to the specification:
```
equation forall a:G, pk:kempkey;
       encodeEC(a) <> encodeKEM(pk).
```
Without this, we cannot apply the IND-CCA or the gapDH assumptions, as the attacker may confuse PQPK and SPK, and we can't apply IND-CCA when the KEM is used with a public key from an SPK. 

Here, using a companion ProVerif model demonstrates that without this assumption, there is indeed a practical attack.

*Feedback 2*: We need to ensure that our extra assumption is in the spec to allow for provable security, and in fact to avoid potential future attacks if one day KEM and DH public keys can indeed be confused.

## Secure DH case

For this setting, we prove authentication and the secrecy of the first sent message. Remark here that for authentication, as X25519 as a small subgroup, we do not in fact have authentication where we can say that both parties use precisely the same one time key OPK (or other DH keys), but only that they use the same modulo this small sub group.

The results in this case are very similar to the previous CryptoVerif analysis of TextSecure, a X3DH like protocol [A].

*Feedback 3*: We cannot prove authentication of the KEM public key, as just under IND-CCA the public key is not tied to the shared secret. See the ProVerif analysis for more details, where the issue is more salient.

## Secure KEM case

In the secure KEM case, we do not look at the authentication case. We prove that secrecy still holds, as long as the signature scheme was secure when the conversation took place. 

*Feedback 4:* Remark that we can only prove the security here assuming that the final AEAD is post-quantum IND-CPA. If the threat model is the PQ setting, one then need to take care of ensuring that the key size is ok for such attackers, but no mention of this is made in the specification.

# File usage

Both scenarios are generated from a single model. The makefile allows to run the proof for both scenarios, using either `make dh` or `make kem`.

# References

[A] N. Kobeissi, K. Bhargavan and B. Blanchet. Automated Verification for Secure Messaging Protocols and their Implementations: A Symbolic and Computational Approach. EuroS&P'17.

[8] K. Cohn-Gordon, C. Cremers, B. Dowling, L. Garratt, and D. Stebila, “A formal security analysis of the signal messaging protocol,” J. Cryptol., vol. 33, no. 4, 2020. https://doi.org/10.1007/s00145-020-09360-1
