/**
 * Mistral AI client configuration and Swedish recipe prompts.
 *
 * This module provides:
 * - Mistral client singleton with API key from Firebase secrets
 * - Swedish-language prompts for recipe extraction
 * - Response type definitions
 */

import { Mistral } from "@mistralai/mistralai";
import { defineSecret } from "firebase-functions/params";

// Define the secret for Mistral API key
export const mistralApiKey = defineSecret("MISTRAL_API_KEY");

// Singleton client instance
let mistralClient: Mistral | null = null;

/**
 * Get or create the Mistral client instance.
 * Must be called within a function that has access to the secret.
 */
export function getMistralClient(apiKey: string): Mistral {
  if (!mistralClient) {
    mistralClient = new Mistral({ apiKey });
  }
  return mistralClient;
}

// =============================================================================
// Swedish Recipe Prompts
// =============================================================================

export const SWEDISH_MEASUREMENTS = `
Svenska mått att känna igen:
- dl (deciliter), cl (centiliter), ml (milliliter), l (liter)
- msk (matsked, 15ml), tsk (tesked, 5ml), krm (kryddmått, 1ml)
- st (stycken), g (gram), kg (kilogram)
- nypa, knippe, klyfta, skiva
`;

export const RECIPE_EXTRACTION_SYSTEM_PROMPT = `Du är expert på att extrahera recept från svensk text.

VIKTIGT:
- Svara ENDAST med valid JSON, ingen annan text
- Behåll svenska ingrediensnamn exakt som de står
- Standardisera mått till svenska format (dl, msk, tsk, etc.)
- Om information saknas, använd null istället för att gissa

${SWEDISH_MEASUREMENTS}

JSON-schema för svaret:
{
  "title": "Receptets namn",
  "description": "Kort beskrivning (max 200 tecken)",
  "portions": antal portioner (heltal),
  "prepTimeMinutes": förberedelsetid i minuter (heltal eller null),
  "cookTimeMinutes": tillagningstid i minuter (heltal eller null),
  "ingredients": [
    {
      "amount": mängd som nummer eller null,
      "unit": "enhet som sträng eller null",
      "name": "ingrediensnamn",
      "preparation": "förberedelse som 'hackad' eller null"
    }
  ],
  "instructions": ["Steg 1", "Steg 2", ...],
  "tags": ["tag1", "tag2"],
  "difficulty": "easy" | "medium" | "hard" | null,
  "source": "källa om känd"
}`;

export const RECIPE_ENHANCEMENT_SYSTEM_PROMPT = `Du är expert på att förbättra och komplettera delvis extraherade recept.

Du får:
1. Delvis extraherad receptdata (kan ha saknade fält)
2. Originaltext som receptet kom från

Din uppgift:
- Fyll i saknade fält från originaltexten
- Korrigera eventuella fel i extraherade data
- Behåll all korrekt information som redan finns
- Svara ENDAST med valid JSON

${SWEDISH_MEASUREMENTS}`;

export const IMAGE_OCR_SYSTEM_PROMPT = `Du är expert på att läsa recept från bilder på svenska.

VIKTIGT:
- Läs all text i bilden noggrant
- Identifiera receptets titel, ingredienser och instruktioner
- Hantera handskriven text om möjligt
- Svara ENDAST med valid JSON i samma schema som vanliga recept

${SWEDISH_MEASUREMENTS}`;

export const SPOKEN_CONTENT_SYSTEM_PROMPT = `Du är expert på att extrahera recept från transkriberat tal (YouTube, TikTok).

VIKTIGT:
- Tal är ofta informellt och ostrukturerat
- Leta efter ingredienser även om de nämns i förbifarten
- Instruktioner kan vara utspridda genom videon
- Ignorera irrelevant prat (intro, outro, sponsorer)
- Svara ENDAST med valid JSON

${SWEDISH_MEASUREMENTS}`;

// =============================================================================
// Response Types
// =============================================================================

export interface ExtractedIngredient {
  amount: number | null;
  unit: string | null;
  name: string;
  preparation: string | null;
}

export interface ExtractedRecipe {
  title: string;
  description: string | null;
  portions: number | null;
  prepTimeMinutes: number | null;
  cookTimeMinutes: number | null;
  ingredients: ExtractedIngredient[];
  instructions: string[];
  tags: string[];
  difficulty: "easy" | "medium" | "hard" | null;
  source: string | null;
}

/**
 * Parse LLM response as JSON, handling potential markdown code blocks.
 */
export function parseRecipeResponse(response: string): ExtractedRecipe | null {
  try {
    // Remove markdown code blocks if present
    let jsonStr = response.trim();
    if (jsonStr.startsWith("```json")) {
      jsonStr = jsonStr.slice(7);
    } else if (jsonStr.startsWith("```")) {
      jsonStr = jsonStr.slice(3);
    }
    if (jsonStr.endsWith("```")) {
      jsonStr = jsonStr.slice(0, -3);
    }
    jsonStr = jsonStr.trim();

    const parsed = JSON.parse(jsonStr);

    // Validate required fields
    if (!parsed.title || !Array.isArray(parsed.ingredients)) {
      console.warn("Invalid recipe structure: missing title or ingredients");
      return null;
    }

    return parsed as ExtractedRecipe;
  } catch (error) {
    console.error("Failed to parse recipe response:", error);
    return null;
  }
}

// =============================================================================
// Model Configuration
// =============================================================================

/** Model for text-based recipe extraction */
export const TEXT_MODEL = "mistral-small-latest";

/** Model for vision/OCR tasks */
export const VISION_MODEL = "pixtral-12b-latest";

/** Maximum tokens for responses */
export const MAX_TOKENS = 2000;

/** Temperature for recipe extraction (lower = more deterministic) */
export const TEMPERATURE = 0.3;
