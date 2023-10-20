This folder contains ProVerif model of the PQXDH protocol, as specified in:

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

## Threat Model

Possible Key Compromise Scenario, with distinct cases:
 - IK secrets (this allow the adversary to compust maliciously signed SPK and PQPK)
 - OPK secrets
 - PQPK secrets
 - SPK secrets
 
Additional Threat Model:
 - The attacker may suddenly be able to compute discrete logs.
 - The attacker may suddendly be able to extract a secret kem key from any public key.
 - Enable confusion between encodeKEM and encodeEC, where honestly generated KEM public keys are weak DH keys and honestly generated DH keys are weak KEM keys. (this scenario is compatible with the gapDH and KEM IND-CCA assumptions)
 - Consider an honest KEM encapsulation result (ss,ct) for some key pair (sk,pk), and an additional keypair (sk',pk').  If the attacker knows (ct,sk,pk'), we consider that the attacker can compute ct' such that decaps(ct',sk') = ss, that is produce a valid encapsulation for pk' of the same shared secret ss. This scenario is compatible with the IND-CCA2 assumption, but is e.g. impossible with Kyber.

## Properties

We try to verify the secrecy of the key computed by the initiator, of the one computed by responder, and the authentication between a responder and an initiator.

For each case, we try to come up with an optimal query, which precisely specifies which set of compromise falsify the query. We thus verify the strongest possible kind of property for each, and notably capture in single queries many classical properties such as KCI, FS, ...

## Attacks

We report here in details on two attacks, that we believe should be fixed on future versions of the protocol. While given the current implementation of PQXDH they do not break the security, the can still happen under the classical gapDH and IND-CCA2 assumptions, and the specification is thus currently impossible to prove under classical assumptions, and may not be secure with later instantiations of primitives.

### KEM/DH confusion

Here, we consider that for some honestly generated SPKB and PQPKB, we may in fact mix them up when sending them to the initiator. 

1) Attacker gets from B, (IKB, SPKB, SPKB_sig, PQPKB, PQPKB_sig)
2) Attacker sends to A (IKB, SPKB, SPKB_sig, SPKB, SPKB_sig), replacing the KEM part with the DH part.
3) A verifies the signature over encodeEC(SPKB) and encodeKEM(SPKB), but as no domain separation is inforced in the spec, the encodeKEM(SPKB) may typically be equal to encodeEC(SPKB) and the check may go through.  Then, after computing the DH  normally, the attacker would compute encaps(SPKB), and once again, there is no reason for this to be secure, and ss may be predictable by the attacker. A then succeeds and output the messages.
4) Here, ss can be computed by the attacker.

So, this attack would completely disable the post DH break down aim.

In addition, it introduces other weird side behaviour, as it introduces further ways to compromise secrecy and authentication when assuming other compromises. The most complex case being where in fact in step 2, we have
2) Attacker sends to A (IKB, PQPKB, PQPKB_sig, SPKB, SPKB_sig), completely swapping the KEM and DH based parts
3) In addition to before, when A generates some EKA, and computes e.g. DH(EKA_s, PQPKB), There is no reason why an honestly generated KEM public key would be a strong valid DH public key, so this may be a weak DH value predicatable by the attacker.  
4) In the end, DH1, DH3 and ss can be computed by the attacker.

### Fix 1

It is is easy to fix this, by simply enforcing that we always have encodeEC(x) <> encodeKEM(y).
Importantly, this attack would also allow to mix up KEM keys for different algorithm, so the KEM byte algo identifier should be a MUST.

### Re-encapsulation confusions

Consider the following execution.
1) Attacker gets from B, (IKB, SPKB, SPKB\_sig, PQPKB, PQPKB\_sig). It also get an additional PQPKB2 and PQPKB2\_sig, which was compromised for some reason.
2) Attacker sends to A (IKB, SPKB, SPKB_sig, PQPKB2, PPKB2_sig).
3) The initiator A proceeds normally, and send back the values (EKA,IKB,SPKB,PQPKB,CT,msg). 
4) Here, the attacker computes SS from CT. (we assumed that PQPKB2 was compromised at step 1).
5) Now, the attacker, not violating IND-CCA2, comes up with CT', valid for PQPKB and such that decap(CT', SPKB_s) = SS.
6) The attacker forwards (EKA,IKB,SPKB,PQPKB,CT',msg) to the responder.
7) The responder succeeds in computing the key.

This makes it so that when a responder accepts a conversation believing to have used some PQPKB, the initiator may have used another one.

Here, the compromise of a PQPK, one time or last resort, that a responder did not use for this session, still allow the attacker to obtain the ss of this responder session. This breaks an usual session independency feature (compromise of ephemeral material of other sessions should not impact the security of an uncompromised session). And it in fact implies that the compromise of a single responder's PQPK implies the compromise of all its other PQPKs.
 
Importantly, Kyber does not allow such reencapsulation by tying the shared secret to the public key, but once again, this is not covered by the IND-CCA assumption.

Defining the precise assumption needed over the KEM to get security is unclear. Notably, compared to other notions such as (w/s)CFR-CCA, called collision freeness, see e.g. [KX, Fig 2], in our case, the attacker does have access to the secret key of one KEM. This seems to indicate that the existing notions are not satisfactory for the current Signal use case.
 
### Fix 2

Adding PQPKB on the initiator side in the AD of the AEAD would for instance fix this.

## Exhaustive Security results

We now report on the multiple results, obtained when enabling all possible compromises, except the encodeEC/encodeKEM confusion.

### Secrecy of the initiator

The key SK computed by the initiator A is secret, unless:
 1) IKB was compromised before the completion of the key exchange
     (this is to be expected, this is essentially a malicious B case)
 2) IKB was compromised after the key exchange, as well as some SPK, and either KEMs are broken or the corresponding PQPK has been compromised
    (the attacker can then trivially recompute DH1 DH2 and DH3 given EKA and IKA, and also ss,  but then, the attacker must have sent to B a malicious OPK)
 3) DH was broken before the key exchange	
    (similar to case 1)
 4) Or DH was broken after the key exchange, and either KEMs are broken or the PQPK compromised
   (similar to case 2)
   
All those cases appear normal, we notably have KCI (compromised IKa does not affect security) and FS implied by our result.   

Remark that using an OPK does not change anything here, as they are not authenticated. But of course, compromising the OPK makes it so that the honest responder will never receive and answer the message.

   
### Secrecy of the responder

The key SK computed by the responder B is secret, unless:
 1) IKA was compromised before the communication.
     (this allows a full impersonation of A)
 2) Some SPKB was compromised before the communication.
    (more surprisingly, but inevitably, this allows a full impersonation of A) 
 3) IKB was compromised before the communication, and some still honest SPK was compromised after and either no OPK was used or it was compromised.
    (see the re-encapsulation above. here, the attacker makes an honest initiator run with some honest SPK, but uses IKB to submit a malicious PQPK. The attacker can then complete the exchange by re-encapsulating the honest ct against an honest PQPK. And once SPK becomes compromise, the attacker can compute everything.
 4) IKB, SPK and PQPK are compromised after the communication, and either no OPK was used or it was compromised.
   (all secret material of B is leaked here, natural case)
 5) IKB, SPK are compromised after the communication, KEMs are broken, and either no OPK was used or it was compromised.  
   (similar to 4)
 6) IKB, SPK are compromised after the communication, a PQPK not used by the responder was compromised, and either no OPK was used or it was compromised.  
   (similar to 3, initiator and responder don't agree on which PQPK was used due to reencapsulation)
 7) DH was broken before the exchange
    (naturally breaks everything)
 8) DH was broken after the exchange, and the PQPK used by the responder was compromised
    (similar to 4)
 9) DH was broken after the exchange, and KEMs are broken
    (similar to 5)
 10) DH was broken after the exchange, and a PQPK not used by the responder was compromised.	
    (similar to 3)
 11) IKb was compromised before the exchange and DH was broken after the exchange.
     (similar to 3)
	 
Here, we have multiple surprising cases, but which are due to the re-encapsulation confusion outlined above. When fixed, this should be simplified.

### Authentication
 
Whenever a responder accepts (resp with or without an OPK), then, there exists an initiator that also accepted (resp with or without an OPK) with the same SPK and PQPK,  unless:
 1) IKA was compromised before the exchange
    ( allows impersonation of A)
 2) A PQPK was compromised before the exchange
    (see re-encapsulation attack, this allows to reencapsulate and have distinct PQPK on both sides, )
 3)	KEM have become broken before the exchange
    (similar to 2)
 4) IKb has been compromised before the exchange
    (similuar to 2, but where IKB allows to sign a dishonnest PQPK, and then reencapsulate ct for a valide one)
 5) Some SPK	was compromised before the exchange
    (knowing SPK allows to impersonate A)
 6) DH has been broken before the exchange.	
	

### Conclusions

Except for two side behaviours, we can see that secrecy does hold, even in the future where either one of DH or KEM would be broken.

# Usage

We use the cpp preprocessor to generate many possible scenarios from a single modeling file.

One can call `./run.sh tag1 ... tagn` with the list of valid tags to verify the corresponding scenario. In the `Makefile`, we provide a few of the main interesting scenarios.

The main possible tags are:
 - ConfuseKemEc - enables the confusion between encodeKEM and encodeEC, and activate a deticated simplified initiator query checking that the secrecy after DH breaks down here.
 - Reach - include the reachaility queries
 - SecrecyInit - Include the initiator secrecy query
 - SecrecyResp - Include the responder secrecy query
 - Authentication - Include the authentication query 
 
Some simplifying tags allow to verify simpler scenarios: 
 - DisableNoOPK - Forces all communications to use an OPK
 - UnbreakableDH - Remove the potential arrival of the discrete log algo


With the Makefile:
 - `make` sets SecrecyInit, SecrecyResp and Authentication, used to reproduce the main results.
 - `make reach` sets Reach, for sanity checks
 - `make confuseKemEc` sets ConfuseKemEc, and to simplify, also UnbreakableDH UnbreakableKEM and DisableNoOPK, enabling to get a trace for the confusion.
 - `make reEncaps` sets a troncated version of SecrecyResp, enabling to obtain an attack trace for the reencapsulation. (also enabling UnbreakableDH UnbreakableKEM DisableNoOPK to quicken up the search)


For each scenario, timings and expected result can be found at the bottom of the file.


# References 

[KX]Anonymity of NIST PQC Round 3 KEMs. Keita Xagawa. EuroCrypt 22.  https://eprint.iacr.org/2021/1323.pdf
