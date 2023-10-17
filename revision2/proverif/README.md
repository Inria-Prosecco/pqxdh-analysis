This folder contains ProVerif model of the PQXDH protocol, as specified in:

[PQXDH] : https://signal.org/docs/specifications/pqxdh/
	  The PQXDH Key Agreement Protocol
	  Revision 2

# Model description   
   
The file models:
- an arbitrary number of clients (devices) communicating with each other
- each device uploads Curve and KEM keys to a server which is fully untrusted (modelled as a public channel)
- each connection consists of one message from the initiator to the responder (with no follow-up messages)
- each connection can optionnaly use an OPK
- PQPK can always be reused, this is a worst case scenario where they are all last resort

## Changelog from revision 1

* The `ConfuseKemEc` capability does not exist anymore, as the assumption that forbides this is explicit in [PQXDH];
* The PQPK public key is included in the AD.
* The authentication properties are stronger, compromising PQPK public keys of other sessions is now useless.
* Consequently, the `ReEncaps` flag is disabled, as it was used to provide an attack which does not exist anymore.

## Threat Model

Possible Key Compromise Scenario, with distinct cases:
 - IK secrets (this allow the adversary to compust maliciously signed SPK and PQPK)
 - OPK secrets
 - PQPK secrets
 - SPK secrets
 
Additional Threat Model:
 - The attacker may suddenly be able to compute discrete logs.
 - The attacker may suddendly be able to extract a secret kem key from any public key.

## Properties

We try to verify the secrecy of the key computed by the initiator, of the one computed by responder, and the authentication between a responder and an initiator.

For each case, we try to come up with an optimal query, which precisely specifies which set of compromise falsify the query. We thus verify the strongest possible kind of property for each, and notably capture in single queries many classical properties such as KCI, FS, ...


## Exhaustive Security results

We now report on the multiple results, obtained when enabling all possible compromises, except the encodeEC/encodeKEM confusion.
/
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
 3) IKB, SPK and PQPK are compromised after the communication, and either no OPK was used or it was compromised.
   (all secret material of B is leaked here, natural case)
 4) IKB, SPK are compromised after the communication, KEMs are broken, and either no OPK was used or it was compromised.  
   (similar to 3)

 5) DH was broken before the exchange
    (naturally breaks everything)
 6) DH was broken after the exchange, and the PQPK used by the responder was compromised
    (similar to 3)
 7) DH was broken after the exchange, and KEMs are broken
    (similar to 5)
	 
Here, all cases
### Authentication
 
Whenever a responder accepts (resp with or without an OPK), then, there exists an initiator that also accepted (resp with or without an OPK) with the same SPK and PQPK,  unless:
 1) IKA was compromised before the exchange
    ( allows impersonation of A)
 2) IKb has been compromised before the exchange
    (similuar to 2, but where IKB allows to sign a dishonnest PQPK, and then reencapsulate ct for a valide one)
 3) Some SPK	was compromised before the exchange
    (knowing SPK allows to impersonate A)
 4) DH has been broken before the exchange.	
	

### Conclusions

We prove in the symbolic model both authentication and secrecy, enumerating precisely the necessary condition so that the attacker can break the properties. Our security properties notably imply forward secrecy, resistance to harvest now decrypt later attacks, resistance to key compromise impersonation, and session independence.

# Usage

We use the cpp preprocessor to generate many possible scenarios from a single modeling file.

One can call `./run.sh tag1 ... tagn` with the list of valid tags to verify the corresponding scenario. In the `Makefile`, we provide a few of the main interesting scenarios.

The main possible tags are:
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

For each scenario, timings and expected result can be found at the bottom of the file.
