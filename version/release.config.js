module.exports = {
  branches: [
    'main'
  ],
  plugins: [
    [
      '@semantic-release/commit-analyzer',
      {
        preset: 'conventionalcommits',
        releaseRules: [
          {breaking: true, release: 'major'},
          {type: 'docs', scope:'README', release: 'patch'},
          {type: 'perf', release: 'patch'},
          {type: 'fix', release: 'patch'},
          {type: 'deps', release: 'patch'},
          {type: 'feat', release: 'minor'},
        ],
        parserOpts: {
          mergePattern: '^Merged PR (\\d+): (\\w*)(?:\\(([\\w\\$\\.\\-\\* ]*)\\))?\\: (.*)$',
          mergeCorrespondence: [
            'id',
            'type',
            'scope',
            'subject'
          ],
          noteKeywords: [
            'BREAKING CHANGE',
            'BREAKING CHANGES'
          ]
        }
      }
    ],
    ['@semantic-release/release-notes-generator', {
      preset: 'conventionalcommits',
      presetConfig: {
        types: [
          {
            type: 'docs',
            section: 'Documentation',
            hidden: false
          },
          {
            type: 'fix',
            section: 'Bug fixes',
            hidden: false
          },
          {
            type: 'feat',
            section: 'New features',
            hidden: false
          },
          {
            type: 'perf',
            section: 'Performance improvement',
            hidden: false
          },
          {
            type: 'style',
            section: 'Code style adjustments',
            hidden: false
          },
          {
            type: 'test',
            section: '(Unit)test cases adjusted',
            hidden: false
          },
          {
            type: 'refactor',
            section: 'Refactor',
            hidden: false
          },
          {
            type: 'deps',
            section: ':arrow_up: Dependency updates',
            hidden: false
          }
        ],
        issueUrlFormat: '//' + process.env.SYSTEM_TEAMPROJECT + '/_workitems/edit/'
      },
      writerOpts: {
        finalizeContext: function (context, options, filteredCommits, keyCommit, commits) {
          const parts = /(.*)\/_git\/(.*)/gm.exec(context.repository);
          const repoUrl = `${context.host}/${context.owner}/${parts[1]}`;
          return {
            ...context,
            repository: null,
            repoUrl,
            commit: `_git/${parts[2]}/commit`,
            issue: '_workitems/edit',
            linkCompare: false
          };
        }
      },
      parserOpts: {
        mergePattern: '^Merged PR (\\d+): (\\w*)(?:\\(([\\w\\$\\.\\-\\* ]*)\\))?\\: (.*)$',
        mergeCorrespondence: [
          'id',
          'type',
          'scope',
          'subject'
        ],
        noteKeywords: [
          'BREAKING CHANGE',
          'BREAKING CHANGES'
        ]
      }
    }],
    [
      '@semantic-release/changelog',
      {
        changelogFile: 'docs/CHANGELOG.md'
      }
    ],
    ['@semantic-release/exec', {
      prepareCmd: "pwsh -NoLogo -NoProfile -NonInteractive -Command ./prepare.ps1 '${ nextRelease.version }' '${ nextRelease.gitHead }' '${ options.repositoryUrl }' '${process.env.CSPROJ}'",
    }],
    [
      '@semantic-release/git',
      {
        message: 'chore(release): ${nextRelease.version} [skip ci]\n\n${nextRelease.notes}',
        assets: [
          'docs/CHANGELOG.md',
          '${process.env.CSPROJ}'
        ]
      }
    ]
  ]
}