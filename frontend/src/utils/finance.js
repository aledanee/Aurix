const DEFAULT_GOLD_SCALE = 8;
const BigIntCtor = window.BigInt;

function powerOfTen(scale) {
  return 10n ** BigIntCtor(scale);
}

function normalizeInteger(value) {
  if (typeof value === 'bigint') {
    return value;
  }

  if (typeof value === 'number' && Number.isFinite(value)) {
    return BigIntCtor(Math.trunc(value));
  }

  const text = String(value ?? '').trim();
  if (!text || !/^-?\d+$/.test(text)) {
    return null;
  }

  return BigIntCtor(text);
}

function roundDivide(numerator, divisor) {
  if (numerator >= 0n) {
    return (numerator + divisor / 2n) / divisor;
  }

  return -((-numerator + divisor / 2n) / divisor);
}

function parseScaledDecimal(value, scale = DEFAULT_GOLD_SCALE) {
  const text = String(value ?? '').trim();
  if (!text) {
    return null;
  }

  const negative = text.startsWith('-');
  const sanitized = negative ? text.slice(1) : text;
  if (!/^\d+(\.\d+)?$/.test(sanitized)) {
    return null;
  }

  const [wholePart = '0', fractionPart = ''] = sanitized.split('.');
  const base = powerOfTen(scale);
  const paddedFraction = (fractionPart + '0'.repeat(scale + 1)).slice(0, scale + 1);
  const fractionDigits = paddedFraction.slice(0, scale) || '0';
  const roundingDigit = paddedFraction.charAt(scale) || '0';

  let scaled = BigIntCtor(wholePart || '0') * base + BigIntCtor(fractionDigits);
  if (roundingDigit >= '5') {
    scaled += 1n;
  }

  return negative ? -scaled : scaled;
}

function formatGroupedInteger(value) {
  return value.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}

function formatScaledInteger(units, scale) {
  const negative = units < 0n;
  const absolute = negative ? -units : units;
  const base = powerOfTen(scale);
  const whole = absolute / base;
  const fraction = (absolute % base).toString().padStart(scale, '0');

  if (scale === 0) {
    return `${negative ? '-' : ''}${formatGroupedInteger(whole.toString())}`;
  }

  return `${negative ? '-' : ''}${formatGroupedInteger(whole.toString())}.${fraction}`;
}

function roundScale(units, currentScale, targetScale) {
  if (targetScale >= currentScale) {
    return units * powerOfTen(targetScale - currentScale);
  }

  return roundDivide(units, powerOfTen(currentScale - targetScale));
}

export function formatEurCents(cents) {
  const value = normalizeInteger(cents);
  if (value == null) {
    return 'EUR0.00';
  }

  const negative = value < 0n;
  const absolute = negative ? -value : value;
  const euros = absolute / 100n;
  const centsPart = (absolute % 100n).toString().padStart(2, '0');

  return `${negative ? '-' : ''}EUR${formatGroupedInteger(euros.toString())}.${centsPart}`.replace('EUR', '€');
}

export function formatGoldGrams(grams, decimals = 4) {
  const units = parseScaledDecimal(grams, DEFAULT_GOLD_SCALE);
  if (units == null) {
    return `${formatScaledInteger(0n, decimals)} g`;
  }

  const roundedUnits = roundScale(units, DEFAULT_GOLD_SCALE, decimals);
  return `${formatScaledInteger(roundedUnits, decimals)} g`;
}

export function estimateGrossEurCents(grams, priceCents) {
  const gramsUnits = parseScaledDecimal(grams, DEFAULT_GOLD_SCALE);
  const centsPerGram = normalizeInteger(priceCents);

  if (gramsUnits == null || centsPerGram == null) {
    return null;
  }

  return roundDivide(gramsUnits * centsPerGram, powerOfTen(DEFAULT_GOLD_SCALE));
}

export function isPositiveGoldAmount(grams) {
  const gramsUnits = parseScaledDecimal(grams, DEFAULT_GOLD_SCALE);
  return gramsUnits != null && gramsUnits > 0n;
}

export function parseEurToCents(eurString) {
  if (eurString == null) return 0;
  const text = String(eurString).trim();
  if (!text) return 0;
  const negative = text.startsWith('-');
  const abs = negative ? text.slice(1) : text;
  const [whole = '0', frac = ''] = abs.split('.');
  const paddedFrac = (frac + '00').slice(0, 2);
  const cents = parseInt(whole, 10) * 100 + parseInt(paddedFrac, 10);
  return negative ? -cents : cents;
}