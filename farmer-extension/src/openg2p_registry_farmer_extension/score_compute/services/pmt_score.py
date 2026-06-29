import logging
from typing import Any

from openg2p_registry_core.interfaces.g2p_score_compute_interface import (
    G2PScoreComputeInterface,
)

_logger = logging.getLogger(__name__)

# Scaled intercept from pmt_formula_farmer_registry.html (0–100 rescaling).
PMT_INTERCEPT = 50.00


class G2PScoreComputeServicePmt(G2PScoreComputeInterface):
    """
    Proxy Means Test (PMT) score for Farmer Registry household records.

    Lower scores indicate greater vulnerability (0 = most vulnerable, 100 = least).
    Weights and lookup maps are configured in
    ``g2p_register_score_contributing_attributes`` for score_type ``PMT``.
    """

    @staticmethod
    def _enum_key(value: Any) -> str:
        if value is None:
            return ""
        if hasattr(value, "value"):
            value = value.value
        return str(value).strip().upper()

    @staticmethod
    def _to_number(value: Any) -> float:
        if value is None:
            return 0.0
        if hasattr(value, "value"):
            value = value.value
        try:
            return float(value)
        except (TypeError, ValueError):
            return 0.0

    def _resolve_contribution(
        self,
        raw_value: Any,
        attribute_config: dict[str, Any],
    ) -> float:
        if attribute_config.get("attribute_computation_required"):
            lookup = attribute_config.get("attribute_computation_value") or {}
            if not isinstance(lookup, dict):
                lookup = {}
            key = self._enum_key(raw_value)
            if key not in lookup:
                _logger.warning("PMT lookup miss for value %r", raw_value)
                return 0.0
            return self._to_number(lookup.get(key))
        return self._to_number(raw_value)

    async def compute_score(
        self,
        link_internal_record_id: str,
        contributing_attribute_config: list[dict[str, Any]],
        contributing_attribute_values: dict[str, Any],
    ) -> float:
        config_by_name = {
            row.get("attribute_name"): row
            for row in contributing_attribute_config
            if isinstance(row, dict) and row.get("attribute_name")
        }

        score = PMT_INTERCEPT
        for attribute_name, raw_value in contributing_attribute_values.items():
            attribute_config = config_by_name.get(attribute_name)
            if not attribute_config:
                continue
            weight = self._to_number(attribute_config.get("attribute_weightage"))
            contribution = self._resolve_contribution(raw_value, attribute_config)
            score += contribution * weight

        rounded = round(score)
        _logger.info(
            "Computed PMT %s for household %s (inputs=%s)",
            rounded,
            link_internal_record_id,
            sorted(contributing_attribute_values.keys()),
        )
        return float(rounded)
