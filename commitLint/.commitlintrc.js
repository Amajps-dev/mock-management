module.exports = {
  extends: ['@commitlint/config-conventional'],
  plugins: ['commitlint-plugin-function-rules'],
  rules: {
    'subject-case': [0], // level: disabled
    'function-rules/subject-case': [
      2, // level: error
      'always',
      (parsed) => {
        const jiraTypes = ['fix','feat'];
        const basicRegexp = '^(([A-Z]+-[0-9]+ )?[a-z])';
        const jiraRegexp = '^([A-Z]+-[0-9]+ [a-z]|[a-z].+#[A-Z]+-[0-9]+$)';

        return parsed.subject?.match(jiraTypes.includes(parsed.type) ? jiraRegexp : basicRegexp)
          ? [true]
          : [false, `subject must contain JIRA ticket number and start with lowercase'. Eg. 'LTT-1234 sample message' or 'sample message #LTT-1234'`];
      },
    ],
  },
};
