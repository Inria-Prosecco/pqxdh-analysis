In this folder, we define a novel security property for KEMs.


# Novel assumption
In CryptoVerif, it is expressed as
```
collision r <-R kem_seed; k <-R kem_enc_seed;  forall ct: ciphertext, pk:kempkey;
	  return(decap(ct,kemskgen(r))= kem_secret(pk,k))
	  <=(KEMcollNew)=> 
	  return(ct=kem_encap(pk,k) && pk = kempkgen(r)).
```	  
In a more classical game based notation, given KEM.Encaps, KEM.Keygen() an KEM.Decaps(), it corresponds to the attacker winning the game BoundPKExp being negligible.

BoundPKExp:
   (pk, sk) <- KEM.Keygen();
   seed <R- {0,1}^k;
   (ct', pk') <- A(pk,sk,seed);
   ss,ct = KEM.Encaps(pk',seed);      
   return ( KEM.Decaps(sk, ct') =ss &  (ct'<> ct || pk'<> pk) )
   
If the attacker wins the game, given a secret and public key pair (pk, sk), it can produce a malicious ciphertext ct' and public key pk' such that the decapsulation of ct' and sk is equal to the shared secret encapsulation against pk', and such that either ct'<> ct  or pk' <> pk.


We prove in the next PQXDH.m4.ocv file that this property is indeed enough to ensure the authentication of the KEM public key in PQXDH revision 1. (using `make dh` or `make kem`)

We also show in a dedicated file Kyber, from https://pq-crystals.org/kyber/data/kyber-specification-round3-20210804.pdf, verifies this assumption.

Insecure:
* MCEliece is insecure, as "modifying one bit in a public key has a significant chance of not
affecting any particular ciphertext" (section 3, https://classic.mceliece.org/mceliece-rationale-20221023.pdf)
