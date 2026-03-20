/**
 * URL safety validation for SSRF prevention.
 *
 * Rejects private IPs, localhost, and non-HTTPS protocols.
 * Used by LLM functions (image URLs) and notification service (imageUrl).
 */

/**
 * Validate that a URL is safe to pass to an external service.
 * Rejects private IPs, localhost, and non-HTTPS protocols to prevent SSRF.
 */
export function isAllowedUrl(url: string): boolean {
  try {
    const parsed = new URL(url);

    // Only allow HTTPS
    if (parsed.protocol !== "https:") return false;

    const hostname = parsed.hostname.toLowerCase();

    // Block localhost and loopback
    if (
      hostname === "localhost" ||
      hostname === "127.0.0.1" ||
      hostname === "[::1]" ||
      hostname === "0.0.0.0"
    ) {
      return false;
    }

    // Block IPv6 private (fc00::/7) and link-local (fe80::/10)
    if (
      hostname.startsWith("fc") ||
      hostname.startsWith("fd") ||
      hostname.startsWith("fe80")
    ) {
      return false;
    }

    // Block private IP ranges
    const parts = hostname.split(".");
    if (parts.length === 4 && parts.every((p) => /^\d+$/.test(p))) {
      const first = parseInt(parts[0]);
      const second = parseInt(parts[1]);
      if (first === 0) return false; // 0.0.0.0/8
      if (first === 10) return false; // 10.0.0.0/8
      if (first === 172 && second >= 16 && second <= 31) return false; // 172.16.0.0/12
      if (first === 192 && second === 168) return false; // 192.168.0.0/16
      if (first === 169 && second === 254) return false; // link-local
    }

    return true;
  } catch {
    return false;
  }
}
