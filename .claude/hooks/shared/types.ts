/**
 * TypeScript type definitions for Claude Code hooks
 */

/** Input received by hooks via stdin */
export interface HookInput {
  prompt?: string;
  tool_name?: string;
  tool_input?: {
    file_path?: string;
    [key: string]: any;
  };
  session_id?: string;
  [key: string]: any;
}

/** Skill activation result */
export interface Skill {
  name: string;
  priority: 'critical' | 'high' | 'medium';
  enforcement: 'enforce' | 'suggest';
  reasons: string[];
  location: string;
}

/** Git context cache */
export interface GitContext {
  branch: string;
  modifiedFiles: string[];
  timestamp: string;
}

/** Skill rules configuration */
export interface SkillRules {
  [skillName: string]: SkillRule;
}

export interface SkillRule {
  type: string;
  enforcement: 'enforce' | 'suggest';
  priority: 'critical' | 'high' | 'medium';
  promptTriggers?: {
    keywords?: string[];
    intentPatterns?: string[];
  };
  fileTriggers?: {
    pathPatterns?: string[];
    contentPatterns?: string[];
  };
}

/** Architecture validation result */
export interface ValidationResult {
  passed: boolean;
  violations: Violation[];
  warnings: Warning[];
}

export interface Violation {
  type: 'critical' | 'style';
  pattern: string;
  line?: number;
  message: string;
  fix?: string;
}

export interface Warning {
  type: string;
  message: string;
  suggestion?: string;
}

/** Prompt logging types */

export interface PromptLogEntry {
  sessionId: string;
  promptId: string;
  timestamp: string;
  prompt: PromptData;
  activatedSkills: SkillActivationLog[];
  gitContext: GitContext | null;
  fileOperations: FileOperationLog[];
  sessionMetadata: SessionMetadata;
  detectedPatterns: DetectedPatterns;
}

export interface PromptData {
  text: string;
  length: number;
  wordCount: number;
  hasCodeBlocks: boolean;
}

export interface SkillActivationLog {
  skillName: string;
  priority: 'critical' | 'high' | 'medium';
  enforcement: 'enforce' | 'suggest';
  matchReason: {
    type: 'keyword' | 'intent' | 'file';
    pattern: string;
    matchedText?: string;
  }[];
  injectionTimeMs?: number;
}

export interface FileOperationLog {
  tool: string;
  filePath: string;
  timestamp: string;
  success: boolean;
  violationsDetected: string[];
  warningsIssued: string[];
}

export interface SessionMetadata {
  conversationTurn: number;
  timeSinceLastPrompt?: number;
  totalPromptsInSession: number;
}

export interface DetectedPatterns {
  isQuestion: boolean;
  isRefactoring: boolean;
  isCreation: boolean;
  isDebugging: boolean;
  isExploration: boolean;
  mentionsArchitecture: boolean;
  mentionsTesting: boolean;
}
