import CONFIG from './config';
import Vue, { PropType } from 'vue';

export interface Suggestion {
  name: string;
  help: string;
  params: SuggestionParam[];

  disabled: boolean;
}

export interface SuggestionParam {
  name: string;
  help?: string;
  options?: string[];
  optionsByToken?: { [key: string]: string[] };
  disabled?: boolean;
  matchedOptions?: string[];
  matchPreview?: string;
}

export default Vue.component('suggestions', {
  props: {
    message: {
      type: String
    },
    
    suggestions: {
      type: Array as PropType<Suggestion[]>
    }
  },
  data() {
    return {};
  },
  computed: {
    currentSuggestions(): Suggestion[] {
      if (this.message === '') {
        return [];
      }
      const currentSuggestions = this.suggestions.filter((s) => {
        if (!s.name.startsWith(this.message)) {
          const suggestionSplitted = s.name.split(' ');
          const messageSplitted = this.message.split(' ');
          for (let i = 0; i < messageSplitted.length; i += 1) {
            if (i >= suggestionSplitted.length) {
              return i < suggestionSplitted.length + s.params.length;
            }
            if (suggestionSplitted[i] !== messageSplitted[i]) {
              return false;
            }
          }
        }
        return true;
      }).slice(0, CONFIG.suggestionLimit);

      currentSuggestions.forEach((s) => {
        // eslint-disable-next-line no-param-reassign
        s.disabled = !s.name.startsWith(this.message);
        const commandContext = this.getCommandContext(s.name);

        s.params.forEach((p, index) => {
          const isActiveParam = commandContext !== null && index === commandContext.argIndex;
          const matches = isActiveParam
            ? this.getParamMatches(p, commandContext.currentToken, commandContext.previousToken)
            : [];

          // eslint-disable-next-line no-param-reassign
          p.disabled = !isActiveParam;
          // eslint-disable-next-line no-param-reassign
          p.matchedOptions = matches;
          // eslint-disable-next-line no-param-reassign
          p.matchPreview = matches.length > 0 ? `Vorschläge: ${matches.join(', ')}` : '';
        });
      });
      return currentSuggestions;
    },
  },
  methods: {
    getCommandContext(commandName: string): { argIndex: number, currentToken: string, previousToken: string } | null {
      if (!this.message.startsWith(commandName)) {
        return null;
      }

      const endsWithSpace = /\s$/.test(this.message);
      const trimmed = this.message.trim();
      const parts = trimmed === '' ? [] : trimmed.split(/\s+/);

      if (parts.length === 0 || parts[0] !== commandName) {
        return null;
      }

      const args = parts.slice(1);
      const argIndex = endsWithSpace ? args.length : Math.max(0, args.length - 1);
      const currentToken = (!endsWithSpace && args.length > 0) ? args[args.length - 1] : '';
      const previousToken = argIndex > 0 ? (args[argIndex - 1] || '') : '';

      return {
        argIndex,
        currentToken,
        previousToken
      };
    },
    getParamMatches(param: SuggestionParam, currentToken: string, previousToken: string): string[] {
      const direct = Array.isArray(param.options) ? param.options : [];
      const grouped = param.optionsByToken || {};
      const byPreviousToken = grouped[(previousToken || '').toLowerCase()] || [];

      const values = [...direct, ...byPreviousToken];
      const seen: { [key: string]: boolean } = {};
      const out: string[] = [];
      const lookup = (currentToken || '').toLowerCase();

      values.forEach((entry) => {
        const value = String(entry || '').trim();
        if (value === '') {
          return;
        }

        const lowered = value.toLowerCase();
        if (seen[lowered]) {
          return;
        }

        if (lookup !== '' && !lowered.startsWith(lookup)) {
          return;
        }

        seen[lowered] = true;
        out.push(value);
      });

      return out.slice(0, CONFIG.suggestionLimit);
    },
  },
});
