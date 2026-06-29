import logging
from typing import Dict

from openg2p_registry_core.interfaces import G2PPayloadEnricherInterface
from sqlalchemy.orm import Session

_logger = logging.getLogger('g2p-payload-enricher-service')


class G2PImportFilePassThroughEnricherService(G2PPayloadEnricherInterface):
    """Pass-through enricher for flat file-import row payloads."""

    def enrich(self, data: Dict, session: Session) -> Dict:
        _logger.info("Processing G2PImportFilePassThroughEnricherService")
        return data if isinstance(data, dict) else {}
