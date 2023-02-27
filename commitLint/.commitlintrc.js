const types = ['feat', 'fix', 'chore', 'docs', 'style', 'refactor', 'test', 'revert', 'build', 'ci', //conventional
                '🎨','⚡️','🔥','🐛','🚑️','✨','📝','🚀','💄','🎉','✅','🔒️','🔐','🔖','🚨','🚧','💚','⬇️', // gitmoji
                '⬆️','📌','👷','📈','♻️','➕','➖','🔧','🔨','🌐','✏️','💩','⏪️','🔀','📦️','👽️','🚚','📄',
                '💥','🍱','♿️','💡','🍻','💬','🗃️','🔊','🔇','👥','🚸','🏗️','📱','🤡','🥚','🙈','📸','⚗️',
                '🔍️','🏷️','🌱','🚩','🥅','💫','🗑️','🛂','🩹','🧐','⚰️','🧪','👔','🩺','🧱','🧑‍💻','💸','🧵','🦺' 
              ];

function isStartingWithElementFromTypes(str) {
  return types.some(types => str.startsWith(types));
}

function getActualSubject(parsed) {
  return parsed.subject || parsed.header.substring(parsed.header.indexOf(' ')+1);
}

function getActualType(parsed){
  return parsed.type || parsed.header.substring(0, parsed.header.indexOf(' '));
}

module.exports = {
  extends: ['@commitlint/config-conventional'],
  plugins: ['commitlint-plugin-function-rules'],
  rules: {
    'subject-case': [0], // level: disabled
    'function-rules/subject-case': [
      2, // level: error
      'always',
      (parsed) => {
        // Check that JIRA ticket is present for those specific changes
        const jiraTypes = ['fix','feat','🐛','🚑️','✨','💄','🔒️','👽️','💥','🍱','♿️','🚸','🚩','🩹'];
        const basicRegexp = '^(([A-Z]+-[0-9]+ )?[a-z])';
        const jiraRegexp = '^([A-Z]+-[0-9]+ [a-z]|[a-z].+#[A-Z]+-[0-9]+$)';

        return getActualSubject(parsed)?.match(jiraTypes.includes(getActualType(parsed)) ? jiraRegexp : basicRegexp)
          ? [true]
          : [false, `Subject must contain JIRA ticket number and start with lowercase'. Eg. 'LTT-1234 sample message' or 'sample message #LTT-1234'`];
      }
    ],
    'type-enum': [0], // level: disabled
    'function-rules/type-enum': [
      2, // level: error
      'always',
      (parsed) => {
        return types.includes(getActualType(parsed))
         ? [true]
        : [false, `Commit type must follow either conventional commit or gitmoji syntax, eg feat: ... or 🐛 ....`];
      }],

    'type-empty': [0], // level: disabled
    'function-rules/type-empty': [
      2, // level: error
      'always',
      (parsed) => {
        return parsed.type || isStartingWithElementFromTypes(parsed.header)
          ? [true]
          : [false, `Commit type must be present and follow either conventional commit or gitmoji syntax, eg feat: ... or 🐛 ....`];
      }],

    'subject-empty': [0], // level: disabled
    'function-rules/subject-empty': [
      2, // level: error
      'always',
      (parsed) => {
        return parsed.subject || isStartingWithElementFromTypes(parsed.header) && parsed.header.length>1
          ? [true]
          : [false, `Subject must be present`];
      }]
    }
};
