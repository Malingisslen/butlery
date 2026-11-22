/**
 * Parser for the photo call's answer: every recipe on one image, in the
 * shape of PHOTO_RECIPES_SCHEMA (`{ recipes: [...] }`).
 *
 * Callers log the counts this parser returns.
 */

import { FinishReason } from "./gemini-sdk";
import {
  parseRecipeResponse,
  stripCodeFences,
  PHOTO_MAX_RECIPES,
  type ExtractedRecipe,
} from "./gemini-client";

export interface PhotoRecipe extends ExtractedRecipe {
  /** Set when this part continues a recipe from a previous page; its title may be "". */
  continuesFromPreviousPage?: boolean;
}

export interface ParsedPhotoRecipes {
  recipes: PhotoRecipe[];
  /** Recipes the answer held that are not in `recipes`. */
  droppedRecipeCount: number;
  /** True when the answer was cut at the token cap and complete recipes were salvaged. */
  salvaged: boolean;
  /** Each kept recipe's index in the answer's array, parallel to `recipes`. */
  recipePositions: number[];
  /**
   * Titled, non-continuation recipes dropped only because no ingredient came
   * back. Every one also counts in `droppedRecipeCount`. Never logged: titles
   * are page text.
   */
  missingIngredients: MissingIngredientsRecipe[];
}

export interface MissingIngredientsRecipe {
  title: string;
  /** Index in the answer's array, so a recovered recipe keeps its page place. */
  position: number;
}

const FINISH_REASONS: ReadonlySet<string> = new Set(Object.values(FinishReason));

/**
 * The candidate's finish reason as one of the SDK's fixed values, so a log
 * field never carries free text. Absent stays undefined.
 */
export function normalizeFinishReason(raw: unknown): string | undefined {
  if (raw === undefined || raw === null) return undefined;
  return typeof raw === "string" && FINISH_REASONS.has(raw) ? raw : "UNRECOGNIZED";
}

/**
 * Complete `{...}` objects at the start of an array body, in order, stopping
 * at the first object the text cuts off. String- and escape-aware, so braces
 * inside a value do not move the depth.
 */
export function scanLeadingArrayObjects(body: string): {
  objects: string[];
  incompleteTail: boolean;
} {
  const objects: string[] = [];
  const n = body.length;
  let i = 0;
  for (;;) {
    while (i < n && /[\s,]/.test(body[i])) i++;
    // The array never closed, so the cap may have hidden another recipe.
    if (i >= n) return { objects, incompleteTail: true };
    if (body[i] !== "{") {
      // `]` ends the array; anything else is a cut-off non-object token.
      return { objects, incompleteTail: body[i] !== "]" };
    }
    const start = i;
    let depth = 0;
    let inStr = false;
    let escape = false;
    let closed = false;
    for (; i < n; i++) {
      const ch = body[i];
      if (escape) {
        escape = false;
      } else if (inStr) {
        if (ch === "\\") escape = true;
        else if (ch === '"') inStr = false;
      } else if (ch === '"') {
        inStr = true;
      } else if (ch === "{") {
        depth++;
      } else if (ch === "}") {
        depth--;
        if (depth === 0) {
          objects.push(body.slice(start, i + 1));
          i++;
          closed = true;
          break;
        }
      }
    }
    if (!closed) return { objects, incompleteTail: true };
  }
}

const RECIPES_ARRAY_OPENER = /^\{\s*"recipes"\s*:\s*\[/;

function salvageTruncated(jsonStr: string): { items: unknown[]; incompleteTail: boolean } {
  const opener = jsonStr.match(RECIPES_ARRAY_OPENER);
  if (!opener) return { items: [], incompleteTail: false };
  const { objects, incompleteTail } = scanLeadingArrayObjects(
    jsonStr.slice(opener[0].length)
  );
  const items: unknown[] = [];
  for (const obj of objects) {
    try {
      items.push(JSON.parse(obj));
    } catch {
      items.push(null);
    }
  }
  return { items, incompleteTail };
}

// parseRecipeResponse requires a title and an ingredient. A continuation may
// lack both, so it borrows these for validation and loses them afterwards.
const PLACEHOLDER_TITLE = "continuation";
const PLACEHOLDER_INGREDIENT = "__continuation_placeholder__";

/**
 * One recipe from the answer, validated by parseRecipeResponse's rules. A
 * continuation may have an empty title and needs one valid ingredient OR one
 * non-empty step; a recipe without a title is kept only as a continuation.
 */
/**
 * The title of an item that is a valid titled recipe in every way except
 * that it has no ingredients, or null. Borrowing one placeholder ingredient
 * tells "only the ingredients are missing" apart from every other rejection.
 */
function titleMissingOnlyIngredients(item: unknown, promptVersion?: string): string | null {
  if (!item || typeof item !== "object" || Array.isArray(item)) return null;
  const obj = item as Record<string, unknown>;
  if (obj.continuesFromPreviousPage === true) return null;
  const title = typeof obj.title === "string" ? obj.title.trim() : "";
  if (!title) return null;
  if (Array.isArray(obj.ingredients) && obj.ingredients.length > 0) return null;
  const withPlaceholder = parseRecipeResponse(
    JSON.stringify({ ...obj, ingredients: [{ name: PLACEHOLDER_INGREDIENT }] }),
    promptVersion
  );
  return withPlaceholder ? withPlaceholder.title : null;
}

function validatePhotoRecipe(item: unknown, promptVersion?: string): PhotoRecipe | null {
  if (!item || typeof item !== "object" || Array.isArray(item)) return null;
  const obj = item as Record<string, unknown>;
  const continuation = obj.continuesFromPreviousPage === true;
  const title = typeof obj.title === "string" ? obj.title.trim() : "";
  if (!title && !continuation) return null;
  if (!continuation) return parseRecipeResponse(JSON.stringify(obj), promptVersion);

  const ingredients = Array.isArray(obj.ingredients) ? obj.ingredients : [];
  const recipe = parseRecipeResponse(
    JSON.stringify({
      ...obj,
      title: title || PLACEHOLDER_TITLE,
      ingredients: [...ingredients, { name: PLACEHOLDER_INGREDIENT }],
    }),
    promptVersion
  );
  if (!recipe) return null;
  recipe.title = title;
  recipe.ingredients = recipe.ingredients.filter((i) => i.name !== PLACEHOLDER_INGREDIENT);
  if (recipe.ingredients.length === 0 && recipe.instructions.length === 0) return null;
  return { ...recipe, continuesFromPreviousPage: true };
}

/**
 * Parse the photo answer. Accepts `{recipes: [...]}` and, for a prompt
 * override written for the one-recipe schema, a bare recipe object. When the
 * answer was cut at the token cap (`finishReason` MAX_TOKENS) and does not
 * parse, the complete recipes at the start of the array are salvaged and the
 * cut-off one counts as dropped. At most PHOTO_MAX_RECIPES are returned;
 * valid recipes past the cap count as dropped.
 */
export function parsePhotoRecipesResponse(
  content: string,
  promptVersion?: string,
  finishReason?: string
): ParsedPhotoRecipes {
  const jsonStr = stripCodeFences(content);
  let items: unknown[];
  let dropped = 0;
  let salvaged = false;
  try {
    const parsed: unknown = JSON.parse(jsonStr);
    if (Array.isArray(parsed)) {
      items = parsed;
    } else if (parsed && typeof parsed === "object") {
      const obj = parsed as Record<string, unknown>;
      if ("recipes" in obj) {
        items = Array.isArray(obj.recipes) ? obj.recipes : [];
      } else {
        items = [obj];
      }
    } else {
      items = [];
    }
  } catch {
    // The parse error is not logged: its message can quote the answer.
    if (finishReason !== FinishReason.MAX_TOKENS) {
      return {
        recipes: [],
        droppedRecipeCount: 0,
        salvaged: false,
        recipePositions: [],
        missingIngredients: [],
      };
    }
    const salvage = salvageTruncated(jsonStr);
    items = salvage.items;
    if (salvage.incompleteTail) dropped++;
    salvaged = items.length > 0;
  }

  const recipes: PhotoRecipe[] = [];
  const recipePositions: number[] = [];
  const missingIngredients: MissingIngredientsRecipe[] = [];
  items.forEach((item, position) => {
    const recipe = validatePhotoRecipe(item, promptVersion);
    if (!recipe || recipes.length >= PHOTO_MAX_RECIPES) {
      dropped++;
      if (!recipe) {
        const title = titleMissingOnlyIngredients(item, promptVersion);
        if (title !== null) missingIngredients.push({ title, position });
      }
      return;
    }
    recipes.push(recipe);
    recipePositions.push(position);
  });
  return {
    recipes,
    droppedRecipeCount: dropped,
    salvaged: salvaged && recipes.length > 0,
    recipePositions,
    missingIngredients,
  };
}

/**
 * The recipe the one-recipe `recipe` field carries: the first titled
 * non-continuation, or, when there is none, the first continuation, so an
 * app that reads one recipe still gets something to review.
 */
export function legacyRecipe(recipes: PhotoRecipe[]): ExtractedRecipe | undefined {
  return (
    recipes.find((r) => r.title !== "" && r.continuesFromPreviousPage !== true) ??
    recipes[0]
  );
}
