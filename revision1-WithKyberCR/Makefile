MAIN = PQXDH

dh:
	m4 -D DH $(MAIN).m4.ocv > _models/$(MAIN).DH.ocv
	time cryptoverif _models/$(MAIN).DH.ocv

kem:
	m4 -D KEM $(MAIN).m4.ocv > _models/$(MAIN).KEM.ocv
	time cryptoverif _models/$(MAIN).KEM.ocv
