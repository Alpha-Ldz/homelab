#!/usr/bin/env python3
"""
SMS Gateway API Wrapper
Supports multiple SMS receiving services (SMS-Activate, 5SIM, GetSMSCode, etc.)
"""

from fastapi import FastAPI, HTTPException, Depends
from pydantic import BaseModel
from typing import Optional, List
import httpx
import os
from datetime import datetime
import asyncio

app = FastAPI(title="SMS Gateway API", version="1.0.0")

# Configuration from environment variables
SMS_ACTIVATE_API_KEY = os.getenv("SMS_ACTIVATE_API_KEY", "")
FIVE_SIM_API_KEY = os.getenv("FIVE_SIM_API_KEY", "")
DEFAULT_PROVIDER = os.getenv("DEFAULT_PROVIDER", "sms-activate")

# Base URLs for different providers
PROVIDERS = {
    "sms-activate": "https://api.sms-activate.org/stubs/handler_api.php",
    "5sim": "https://5sim.net/v1",
}


class NumberRequest(BaseModel):
    service: str
    country: Optional[str] = "0"  # 0 = Russia, or country code
    provider: Optional[str] = None


class NumberResponse(BaseModel):
    id: str
    number: str
    provider: str
    service: str
    cost: float


class SMSResponse(BaseModel):
    id: str
    code: Optional[str] = None
    full_text: Optional[str] = None
    status: str


class ProviderBalance(BaseModel):
    provider: str
    balance: float


# SMS-Activate API Functions
async def sms_activate_get_number(service: str, country: str = "0") -> dict:
    """Get a number from SMS-Activate"""
    if not SMS_ACTIVATE_API_KEY:
        raise HTTPException(status_code=400, detail="SMS-Activate API key not configured")

    async with httpx.AsyncClient() as client:
        response = await client.get(
            PROVIDERS["sms-activate"],
            params={
                "api_key": SMS_ACTIVATE_API_KEY,
                "action": "getNumber",
                "service": service,
                "country": country,
            },
        )

        result = response.text
        if "ACCESS_NUMBER" in result:
            parts = result.split(":")
            return {
                "id": parts[1],
                "number": parts[2],
                "provider": "sms-activate",
                "cost": 0.0,  # Cost would need separate API call
            }
        else:
            raise HTTPException(status_code=400, detail=f"Error: {result}")


async def sms_activate_get_status(activation_id: str) -> dict:
    """Get SMS status from SMS-Activate"""
    if not SMS_ACTIVATE_API_KEY:
        raise HTTPException(status_code=400, detail="SMS-Activate API key not configured")

    async with httpx.AsyncClient() as client:
        response = await client.get(
            PROVIDERS["sms-activate"],
            params={
                "api_key": SMS_ACTIVATE_API_KEY,
                "action": "getStatus",
                "id": activation_id,
            },
        )

        result = response.text
        if "STATUS_OK" in result:
            code = result.split(":")[1]
            return {"status": "completed", "code": code, "full_text": code}
        elif "STATUS_WAIT_CODE" in result:
            return {"status": "waiting", "code": None, "full_text": None}
        else:
            return {"status": result.lower(), "code": None, "full_text": None}


async def sms_activate_get_balance() -> float:
    """Get balance from SMS-Activate"""
    if not SMS_ACTIVATE_API_KEY:
        return 0.0

    async with httpx.AsyncClient() as client:
        response = await client.get(
            PROVIDERS["sms-activate"],
            params={
                "api_key": SMS_ACTIVATE_API_KEY,
                "action": "getBalance",
            },
        )

        result = response.text
        if "ACCESS_BALANCE" in result:
            return float(result.split(":")[1])
        return 0.0


# 5SIM API Functions
async def five_sim_get_number(service: str, country: str = "russia") -> dict:
    """Get a number from 5SIM"""
    if not FIVE_SIM_API_KEY:
        raise HTTPException(status_code=400, detail="5SIM API key not configured")

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{PROVIDERS['5sim']}/user/buy/activation/{country}/any/{service}",
            headers={"Authorization": f"Bearer {FIVE_SIM_API_KEY}"},
        )

        if response.status_code == 200:
            data = response.json()
            return {
                "id": str(data["id"]),
                "number": data["phone"],
                "provider": "5sim",
                "cost": data["price"],
            }
        else:
            raise HTTPException(status_code=400, detail=f"Error: {response.text}")


async def five_sim_get_status(activation_id: str) -> dict:
    """Get SMS status from 5SIM"""
    if not FIVE_SIM_API_KEY:
        raise HTTPException(status_code=400, detail="5SIM API key not configured")

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{PROVIDERS['5sim']}/user/check/{activation_id}",
            headers={"Authorization": f"Bearer {FIVE_SIM_API_KEY}"},
        )

        if response.status_code == 200:
            data = response.json()
            status = data.get("status", "")

            if status == "RECEIVED":
                return {
                    "status": "completed",
                    "code": data.get("sms", [{}])[0].get("code"),
                    "full_text": data.get("sms", [{}])[0].get("text"),
                }
            elif status in ["PENDING", "WAITING"]:
                return {"status": "waiting", "code": None, "full_text": None}
            else:
                return {"status": status.lower(), "code": None, "full_text": None}
        return {"status": "error", "code": None, "full_text": None}


async def five_sim_get_balance() -> float:
    """Get balance from 5SIM"""
    if not FIVE_SIM_API_KEY:
        return 0.0

    async with httpx.AsyncClient() as client:
        response = await client.get(
            f"{PROVIDERS['5sim']}/user/profile",
            headers={"Authorization": f"Bearer {FIVE_SIM_API_KEY}"},
        )

        if response.status_code == 200:
            data = response.json()
            return float(data.get("balance", 0))
        return 0.0


# API Endpoints
@app.get("/")
async def root():
    """API root endpoint"""
    return {
        "name": "SMS Gateway API",
        "version": "1.0.0",
        "providers": list(PROVIDERS.keys()),
        "configured_providers": [
            p for p in ["sms-activate", "5sim"]
            if (p == "sms-activate" and SMS_ACTIVATE_API_KEY) or (p == "5sim" and FIVE_SIM_API_KEY)
        ],
    }


@app.post("/number", response_model=NumberResponse)
async def get_number(request: NumberRequest):
    """
    Get a phone number for receiving SMS

    Parameters:
    - service: Service code (e.g., 'vk', 'go', 'wa' for WhatsApp, 'tg' for Telegram)
    - country: Country code (default '0' for Russia in SMS-Activate, 'russia' for 5SIM)
    - provider: Provider to use ('sms-activate' or '5sim', defaults to DEFAULT_PROVIDER)
    """
    provider = request.provider or DEFAULT_PROVIDER

    try:
        if provider == "sms-activate":
            result = await sms_activate_get_number(request.service, request.country)
        elif provider == "5sim":
            result = await five_sim_get_number(request.service, request.country)
        else:
            raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")

        return NumberResponse(
            id=result["id"],
            number=result["number"],
            provider=result["provider"],
            service=request.service,
            cost=result["cost"],
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/sms/{activation_id}", response_model=SMSResponse)
async def get_sms(activation_id: str, provider: Optional[str] = None):
    """
    Get SMS for an activation

    Parameters:
    - activation_id: The activation ID received from /number endpoint
    - provider: Provider used for the activation
    """
    provider = provider or DEFAULT_PROVIDER

    try:
        if provider == "sms-activate":
            result = await sms_activate_get_status(activation_id)
        elif provider == "5sim":
            result = await five_sim_get_status(activation_id)
        else:
            raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")

        return SMSResponse(
            id=activation_id,
            code=result.get("code"),
            full_text=result.get("full_text"),
            status=result["status"],
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/balance", response_model=List[ProviderBalance])
async def get_balance():
    """Get balance for all configured providers"""
    balances = []

    if SMS_ACTIVATE_API_KEY:
        try:
            balance = await sms_activate_get_balance()
            balances.append(ProviderBalance(provider="sms-activate", balance=balance))
        except:
            pass

    if FIVE_SIM_API_KEY:
        try:
            balance = await five_sim_get_balance()
            balances.append(ProviderBalance(provider="5sim", balance=balance))
        except:
            pass

    return balances


@app.post("/cancel/{activation_id}")
async def cancel_activation(activation_id: str, provider: Optional[str] = None):
    """Cancel an activation and get refund (if supported by provider)"""
    provider = provider or DEFAULT_PROVIDER

    if provider == "sms-activate":
        if not SMS_ACTIVATE_API_KEY:
            raise HTTPException(status_code=400, detail="SMS-Activate API key not configured")

        async with httpx.AsyncClient() as client:
            response = await client.get(
                PROVIDERS["sms-activate"],
                params={
                    "api_key": SMS_ACTIVATE_API_KEY,
                    "action": "setStatus",
                    "status": "8",  # Cancel
                    "id": activation_id,
                },
            )
            return {"status": "cancelled", "response": response.text}

    elif provider == "5sim":
        if not FIVE_SIM_API_KEY:
            raise HTTPException(status_code=400, detail="5SIM API key not configured")

        async with httpx.AsyncClient() as client:
            response = await client.get(
                f"{PROVIDERS['5sim']}/user/cancel/{activation_id}",
                headers={"Authorization": f"Bearer {FIVE_SIM_API_KEY}"},
            )
            return {"status": "cancelled", "response": response.text}

    else:
        raise HTTPException(status_code=400, detail=f"Unknown provider: {provider}")


if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8080)
