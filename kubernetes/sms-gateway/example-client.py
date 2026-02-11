#!/usr/bin/env python3
"""
Exemple de client Python pour l'API SMS Gateway

Usage:
    python example-client.py --service go --country 0
    python example-client.py --service tg --provider 5sim --country russia
"""

import argparse
import requests
import time
import sys
from typing import Optional, Tuple


class SMSGatewayClient:
    """Client pour l'API SMS Gateway"""

    def __init__(self, base_url: str):
        self.base_url = base_url.rstrip("/")
        self.session = requests.Session()

    def get_number(
        self, service: str, country: str = "0", provider: Optional[str] = None
    ) -> Tuple[str, str, float]:
        """
        Obtenir un numéro de téléphone

        Args:
            service: Code du service (go, tg, wa, etc.)
            country: Code pays (0 pour Russie dans SMS-Activate, 'russia' pour 5SIM)
            provider: Provider à utiliser (sms-activate, 5sim)

        Returns:
            Tuple (activation_id, phone_number, cost)
        """
        payload = {"service": service, "country": country}
        if provider:
            payload["provider"] = provider

        response = self.session.post(f"{self.base_url}/number", json=payload)
        response.raise_for_status()

        data = response.json()
        return data["id"], data["number"], data.get("cost", 0.0)

    def get_sms(
        self, activation_id: str, provider: Optional[str] = None
    ) -> Tuple[str, Optional[str], Optional[str]]:
        """
        Récupérer le SMS pour une activation

        Args:
            activation_id: ID de l'activation
            provider: Provider utilisé

        Returns:
            Tuple (status, code, full_text)
        """
        params = {}
        if provider:
            params["provider"] = provider

        response = self.session.get(
            f"{self.base_url}/sms/{activation_id}", params=params
        )
        response.raise_for_status()

        data = response.json()
        return data["status"], data.get("code"), data.get("full_text")

    def wait_for_sms(
        self,
        activation_id: str,
        provider: Optional[str] = None,
        timeout: int = 300,
        poll_interval: int = 5,
    ) -> Optional[str]:
        """
        Attendre la réception du SMS

        Args:
            activation_id: ID de l'activation
            provider: Provider utilisé
            timeout: Timeout en secondes (défaut: 5 minutes)
            poll_interval: Intervalle de polling en secondes (défaut: 5s)

        Returns:
            Code de vérification ou None si timeout/erreur
        """
        start_time = time.time()

        while (time.time() - start_time) < timeout:
            status, code, full_text = self.get_sms(activation_id, provider)

            if status == "completed":
                return code
            elif status == "waiting":
                print(f"⏳ Attente... ({int(time.time() - start_time)}s)")
                time.sleep(poll_interval)
            else:
                print(f"❌ Statut inattendu: {status}")
                return None

        print("⏰ Timeout atteint")
        return None

    def cancel_activation(
        self, activation_id: str, provider: Optional[str] = None
    ) -> bool:
        """
        Annuler une activation

        Args:
            activation_id: ID de l'activation
            provider: Provider utilisé

        Returns:
            True si succès
        """
        params = {}
        if provider:
            params["provider"] = provider

        response = self.session.post(
            f"{self.base_url}/cancel/{activation_id}", params=params
        )
        response.raise_for_status()
        return True

    def get_balance(self) -> dict:
        """
        Obtenir le solde de tous les providers configurés

        Returns:
            Dictionnaire {provider: balance}
        """
        response = self.session.get(f"{self.base_url}/balance")
        response.raise_for_status()

        balances = response.json()
        return {item["provider"]: item["balance"] for item in balances}


def main():
    parser = argparse.ArgumentParser(description="Client SMS Gateway")
    parser.add_argument(
        "--url",
        default="https://sms.yourdomain.com",
        help="URL de l'API SMS Gateway",
    )
    parser.add_argument(
        "--service", required=True, help="Code du service (go, tg, wa, fb, etc.)"
    )
    parser.add_argument("--country", default="0", help="Code pays (défaut: 0)")
    parser.add_argument(
        "--provider", help="Provider (sms-activate ou 5sim)", default=None
    )
    parser.add_argument(
        "--timeout", type=int, default=300, help="Timeout en secondes (défaut: 300)"
    )
    parser.add_argument(
        "--balance", action="store_true", help="Afficher le solde uniquement"
    )

    args = parser.parse_args()

    client = SMSGatewayClient(args.url)

    # Mode balance uniquement
    if args.balance:
        print("💰 Soldes:")
        balances = client.get_balance()
        for provider, balance in balances.items():
            print(f"  {provider}: ${balance:.2f}")
        return 0

    # Workflow complet
    print(f"🚀 Demande d'un numéro pour le service '{args.service}'")
    print(f"   Pays: {args.country}")
    if args.provider:
        print(f"   Provider: {args.provider}")

    try:
        # 1. Obtenir un numéro
        activation_id, phone_number, cost = client.get_number(
            args.service, args.country, args.provider
        )

        print(f"\n✅ Numéro obtenu:")
        print(f"   📱 Numéro: {phone_number}")
        print(f"   🔑 ID: {activation_id}")
        print(f"   💵 Coût: ${cost:.2f}")

        print(f"\n📲 Utilisez ce numéro pour recevoir le SMS")
        print(f"⏳ Attente du SMS (timeout: {args.timeout}s)...\n")

        # 2. Attendre le SMS
        code = client.wait_for_sms(
            activation_id, args.provider, timeout=args.timeout
        )

        if code:
            print(f"\n🎉 Code de vérification reçu: {code}")
            return 0
        else:
            print(
                f"\n❌ Échec de la réception du SMS. Tentative d'annulation..."
            )
            try:
                client.cancel_activation(activation_id, args.provider)
                print("✅ Activation annulée (remboursement si supporté)")
            except Exception as e:
                print(f"⚠️  Erreur lors de l'annulation: {e}")
            return 1

    except requests.exceptions.RequestException as e:
        print(f"\n❌ Erreur API: {e}")
        return 1
    except KeyboardInterrupt:
        print(f"\n⚠️  Interruption utilisateur")
        return 130


# Exemples de codes de service populaires
SERVICE_CODES = {
    "go": "Google/Gmail",
    "wa": "WhatsApp",
    "tg": "Telegram",
    "fb": "Facebook",
    "ig": "Instagram",
    "tw": "Twitter",
    "vk": "VKontakte",
    "ok": "Odnoklassniki",
    "vi": "Viber",
}


if __name__ == "__main__":
    print("=" * 60)
    print("SMS Gateway Client")
    print("=" * 60)
    print()

    # Afficher les codes de service disponibles
    if len(sys.argv) == 1 or "--help" in sys.argv or "-h" in sys.argv:
        print("Codes de service populaires:")
        for code, name in SERVICE_CODES.items():
            print(f"  {code:4} - {name}")
        print()

    sys.exit(main())
