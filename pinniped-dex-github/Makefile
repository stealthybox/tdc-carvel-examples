IP=$(shell hostname -I | cut -d' ' -f1)

IP_DASHED=$(shell echo $(IP) | tr '.:' -)

DEX_HOST="dex-$(IP_DASHED).sslip.io"
PINNIPED_HOST="pinniped-$(IP_DASHED).sslip.io"

INGRESS_CLASS="" # optional
CLUSTER_ISSUER="" # optional

ENV="dev" # <dev|prod>


ALL_FILES= \
-f config \
-f __ytt_lib \

CONCIERGE_FILES= \
-f config/jwt-auth.ytt.yaml \
-f config/_schema.ytt.yaml \
-f config/values.yaml \
-f __ytt_lib/pinniped-concierge \

INGRESS_VALUES= \
--data-value dex_host="$(DEX_HOST)" \
--data-value pinniped_host="$(PINNIPED_HOST)" \
--data-value ingress_class="$(INGRESS_CLASS)" \

MKCERT_VALUES= \
--data-value-file dex_tls.crt=./mkcert/sslip.io+6.pem \
--data-value-file dex_tls.key=./mkcert/sslip.io+6-key.pem \
--data-value-file pinniped_supervisor_tls.crt=./mkcert/sslip.io+6.pem \
--data-value-file pinniped_supervisor_tls.key=./mkcert/sslip.io+6-key.pem \

ACME_VALUES= \
--data-value-yaml cert_manager.tls_acme=true \
--data-value cert_manager.cluster_issuer=$(CLUSTER_ISSUER) \


# this target is great for outputting the generated domains for a dev ENV
hosts:
	@echo dex_host:
	@echo "  $(DEX_HOST)"
	@echo pinniped_host:
	@echo "  $(PINNIPED_HOST)"

# pinniped-dex-github
# these targets deploy the dex, the pinniped supervisor + concierge, and configs
# for ingress, tls, dex's connection to GitHub, and pinniped to dex
ytt-dev:
	@ytt $(ALL_FILES) $(INGRESS_VALUES) $(MKCERT_VALUES)

ytt-prod:
	@ytt $(ALL_FILES) $(INGRESS_VALUES) $(ACME_VALUES)

dry:
	@$(MAKE) ytt-$(ENV) | kapp deploy -f- -a pinniped-dex-github

deploy:
	@$(MAKE) ytt-$(ENV) | kapp deploy -f- -a pinniped-dex-github --yes

remove:
	@kapp delete -a pinniped-dex-github --yes

# concierge
# these targets deploy just the concierge
ytt-concierge-dev:
	@ytt $(CONCIERGE_FILES) $(INGRESS_VALUES) $(MKCERT_VALUES)

ytt-concierge-prod:
	@ytt $(CONCIERGE_FILES) $(INGRESS_VALUES)

dry-concierge:
	$(MAKE) ytt-concierge-$(ENV) | kapp deploy -f- -a pinniped-concierge

deploy-concierge:
	@$(MAKE) ytt-concierge-$(ENV) | kapp deploy -f- -a pinniped-concierge --yes

remove-concierge:
	@kapp delete -a pinniped-concierge --yes
