/**
 * Puts a photo's base64 into the canonical form Vertex AI accepts.
 *
 * App builds whose `OcrRecipeImageRequest` still uses the hand-written
 * `_encodeBase64` write the final 4-character group wrong unless the byte
 * count is 2 more than a multiple of 3, and Vertex refuses such a string with
 * 400 "Invalid value at 'contents[0].parts[0].inline_data.data' (TYPE_BYTES)".
 * Those builds stay installed, so the server repairs the string. The
 * `ocr_recipe_image.base64_repaired` log line measures how often; the repair
 * can go once that line stops appearing.
 */

const DATA_URL_PREFIX = /^data:[^,]*,/;
const BASE64_BODY = /^[A-Za-z0-9+/]*={0,2}$/;

export interface PreparedImageBase64 {
  base64: string;
  /** Whether the canonical string differs from what the client sent. */
  repaired: boolean;
  /** Whether a JPEG got back the end-of-image byte the bad group dropped. */
  jpegEndRestored: boolean;
}

/**
 * Returns null when the input is not base64 or decodes to nothing, so the
 * caller refuses it instead of sending Vertex an empty or invented image.
 */
export function prepareImageBase64(supplied: string): PreparedImageBase64 | null {
  const body = supplied.replace(DATA_URL_PREFIX, "").replace(/\s+/g, "");
  if (!BASE64_BODY.test(body)) return null;

  let bytes = Buffer.from(body, "base64");
  if (bytes.length === 0) return null;

  // Only a JPEG has a known final byte: it ends FF D9. A lost D9 leaves the
  // decoded image ending in FF. Other formats keep their bytes as decoded.
  let jpegEndRestored = false;
  const isJpeg = bytes.length >= 3 &&
    bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff;
  if (isJpeg && bytes[bytes.length - 1] === 0xff) {
    bytes = Buffer.concat([bytes, Buffer.from([0xd9])]);
    jpegEndRestored = true;
  }

  const base64 = bytes.toString("base64");
  return { base64, repaired: base64 !== body, jpegEndRestored };
}
