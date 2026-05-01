"""Firebase Cloud Messaging helper."""
import logging
import os

logger = logging.getLogger(__name__)

_initialized = False


def _init() -> bool:
    global _initialized
    if _initialized:
        return True
    try:
        import firebase_admin
        from firebase_admin import credentials
        sa_path = os.path.join(os.path.dirname(__file__), "../../firebase-service-account.json")
        sa_path = os.path.abspath(sa_path)
        if not os.path.exists(sa_path):
            logger.warning("firebase-service-account.json not found at %s", sa_path)
            return False
        cred = credentials.Certificate(sa_path)
        if not firebase_admin._apps:
            firebase_admin.initialize_app(cred)
        _initialized = True
        return True
    except Exception as e:
        logger.error("FCM init failed: %s", e)
        return False


async def send_push(
    tokens: list[str],
    title: str,
    body: str,
    data: dict | None = None,
    data_only: bool = False,
) -> None:
    """Send FCM push notification to a list of device tokens. Silently ignores failures.

    Pass data_only=True for call notifications — omits the notification block so the
    FCM background handler runs even when the app is killed (Android). flutter_callkit_incoming
    will show its own full-screen incoming call UI instead.
    """
    if not tokens:
        return
    if not _init():
        return
    try:
        from firebase_admin import messaging
        message = messaging.MulticastMessage(
            tokens=tokens,
            notification=None if data_only else messaging.Notification(title=title, body=body),
            data={k: str(v) for k, v in (data or {}).items()},
            android=messaging.AndroidConfig(priority="high"),
            apns=messaging.APNSConfig(
                headers={"apns-priority": "10"},
                payload=messaging.APNSPayload(
                    aps=messaging.Aps(content_available=True),
                ),
            ) if data_only else None,
        )
        resp = messaging.send_each_for_multicast(message)
        logger.info("FCM sent %d/%d success", resp.success_count, len(tokens))
    except Exception as e:
        logger.error("FCM send failed: %s", e)
