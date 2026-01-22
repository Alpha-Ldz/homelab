.PHONY: help deploy delete status logs logs-provider logs-adb devices check-usb clean restart

help: ## Afficher cette aide
	@echo "STF (Smartphone Test Farm) - Makefile"
	@echo ""
	@echo "Commandes disponibles :"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'

deploy: ## Déployer STF sur Kubernetes
	@echo "Déploiement de STF..."
	@./deploy.sh

delete: ## Supprimer complètement STF
	@echo "Suppression du namespace stf..."
	kubectl delete namespace stf

status: ## Afficher l'état de tous les pods et services
	@echo "=== Pods ==="
	@kubectl get pods -n stf
	@echo ""
	@echo "=== Services ==="
	@kubectl get svc -n stf
	@echo ""
	@echo "=== Ingress ==="
	@kubectl get ingress -n stf

logs: ## Afficher les logs de l'app principale
	kubectl logs -n stf -l app=stf-app --tail=100 -f

logs-provider: ## Afficher les logs du provider STF
	kubectl logs -n stf -l app=stf-provider -c provider --tail=100 -f

logs-adb: ## Afficher les logs du serveur ADB
	kubectl logs -n stf -l app=stf-provider -c adb-server --tail=100 -f

logs-api: ## Afficher les logs de l'API
	kubectl logs -n stf -l app=stf-api --tail=100 -f

logs-rethinkdb: ## Afficher les logs de RethinkDB
	kubectl logs -n stf -l app=rethinkdb --tail=100 -f

devices: ## Lister les devices Android détectés
	@echo "Devices Android détectés par ADB :"
	@kubectl exec -n stf -l app=stf-provider -c adb-server -- adb devices

check-usb: ## Vérifier la détection USB (sur le host)
	@echo "Périphériques USB connectés :"
	@lsusb | grep -i "android\|google\|samsung\|xiaomi\|oppo\|huawei" || echo "Aucun device Android trouvé via lsusb"

restart-provider: ## Redémarrer le provider (utile si device non détecté)
	@echo "Redémarrage du provider..."
	kubectl rollout restart daemonset stf-provider -n stf
	@echo "Attente du redémarrage..."
	@sleep 10
	@kubectl get pods -n stf -l app=stf-provider

restart-app: ## Redémarrer l'application web
	kubectl rollout restart deployment app -n stf

restart-rethinkdb: ## Redémarrer RethinkDB (attention : peut causer des interruptions)
	kubectl rollout restart deployment rethinkdb -n stf

clean: ## Nettoyer les ressources (garde les PVC)
	@echo "Suppression des deployments et daemonsets..."
	kubectl delete deployment,daemonset,service,ingress -n stf --all
	@echo "Les PVC sont conservés. Pour les supprimer : kubectl delete pvc -n stf --all"

shell-provider: ## Ouvrir un shell dans le provider
	kubectl exec -n stf -l app=stf-provider -c provider -it -- /bin/bash

shell-adb: ## Ouvrir un shell dans le container ADB
	kubectl exec -n stf -l app=stf-provider -c adb-server -it -- /bin/bash

test-api: ## Tester l'API (lister les devices)
	@echo "Test de l'API STF :"
	@curl -s http://stf.local/api/v1/devices | jq . || echo "Erreur : jq non installé ou API injoignable"

open: ## Ouvrir l'interface web dans le navigateur
	@echo "Ouverture de http://stf.local dans le navigateur..."
	@xdg-open http://stf.local 2>/dev/null || open http://stf.local 2>/dev/null || echo "Ouvrez manuellement : http://stf.local"

watch: ## Surveiller l'état des pods en temps réel
	watch -n 2 kubectl get pods -n stf

describe-provider: ## Décrire le provider (debug)
	kubectl describe daemonset stf-provider -n stf

events: ## Afficher les events récents du namespace stf
	kubectl get events -n stf --sort-by='.lastTimestamp'

port-forward-rethinkdb: ## Port-forward RethinkDB admin (8080)
	@echo "Port-forward RethinkDB admin sur http://localhost:8080"
	kubectl port-forward -n stf svc/rethinkdb 8080:8080

update-configmap: ## Mettre à jour le ConfigMap (puis redémarrer les services)
	kubectl apply -f base/configmap.yaml
	@echo "ConfigMap mis à jour. Pensez à redémarrer les services concernés."
