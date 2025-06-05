### MCP Server Implementation

**terraform/modules/claude-code/templates/mcp_server.js**
```javascript
import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import { ListToolsRequestSchema, CallToolRequestSchema } from '@modelcontextprotocol/sdk/types.js';
import { exec } from 'child_process';
import { promisify } from 'util';

const execAsync = promisify(exec);
const GITHUB_TOKEN = "${github_token}";

class ClaudeMCPServer {
  constructor() {
    this.server = new Server(
      { name: 'claude-mcp-server', version: '1.0.0' },
      { capabilities: { tools: {}, resources: {}, prompts: {} } }
    );
    
    this.setupHandlers();
  }

  setupHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: 'github_pr_view',
          description: 'View GitHub pull request details',
          inputSchema: {
            type: 'object',
            properties: {
              pr_number: { type: 'number', description: 'PR number to view' },
              repo: { type: 'string', description: 'Repository in owner/name format' }
            },
            required: ['pr_number']
          }
        },
        {
          name: 'github_pr_comment',
          description: 'Add comment to GitHub pull request',
          inputSchema: {
            type: 'object',
            properties: {
              pr_number: { type: 'number', description: 'PR number' },
              comment: { type: 'string', description: 'Comment text' },
              repo: { type: 'string', description: 'Repository in owner/name format' }
            },
            required: ['pr_number', 'comment']
          }
        },
        {
          name: 'github_pr_create',
          description: 'Create new GitHub pull request',
          inputSchema: {
            type: 'object',
            properties: {
              title: { type: 'string', description: 'PR title' },
              body: { type: 'string', description: 'PR description' },
              head: { type: 'string', description: 'Source branch' },
              base: { type: 'string', description: 'Target branch' },
              repo: { type: 'string', description: 'Repository in owner/name format' }
            },
            required: ['title', 'head', 'base']
          }
        },
        {
          name: 'code_analysis',
          description: 'Analyze code changes in repository',
          inputSchema: {
            type: 'object',
            properties: {
              path: { type: 'string', description: 'Path to analyze' },
              type: { type: 'string', enum: ['security', 'performance', 'quality'], description: 'Analysis type' }
            },
            required: ['path']
          }
        }
      ]
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      const { name, arguments: args } = request.params;

      try {
        switch (name) {
          case 'github_pr_view':
            return await this.viewPullRequest(args);
          case 'github_pr_comment':
            return await this.commentOnPR(args);
          case 'github_pr_create':
            return await this.createPullRequest(args);
          case 'code_analysis':
            return await this.analyzeCode(args);
          default:
            throw new Error(`Unknown tool: ${name}`);
        }
      } catch (error) {
        return {
          content: [{ type: 'text', text: `Error: ${error.message}` }],
          isError: true
        };
      }
    });
  }

  async viewPullRequest(args) {
    const { pr_number, repo } = args;
    const repoArg = repo ? `--repo ${repo}` : '';
    
    const { stdout } = await execAsync(`gh pr view ${pr_number} ${repoArg} --json title,body,state,author,files,comments`);
    const prData = JSON.parse(stdout);
    
    return {
      content: [{
        type: 'text',
        text: `PR #${pr_number}: ${prData.title}
        
**Status:** ${prData.state}
**Author:** ${prData.author.login}

**Description:**
${prData.body}

**Files Changed:** ${prData.files.length}
**Comments:** ${prData.comments.length}`
      }]
    };
  }

  async commentOnPR(args) {
    const { pr_number, comment, repo } = args;
    const repoArg = repo ? `--repo ${repo}` : '';
    
    await execAsync(`gh pr comment ${pr_number} ${repoArg} --body "${comment}"`);
    
    return {
      content: [{
        type: 'text',
        text: `Comment added to PR #${pr_number}`
      }]
    };
  }

  async createPullRequest(args) {
    const { title, body, head, base, repo } = args;
    const repoArg = repo ? `--repo ${repo}` : '';
    const bodyArg = body ? `--body "${body}"` : '';
    
    const { stdout } = await execAsync(`gh pr create --title "${title}" ${bodyArg} --head ${head} --base ${base} ${repoArg}`);
    
    return {
      content: [{
        type: 'text',
        text: `Pull request created: ${stdout.trim()}`
      }]
    };
  }

  async analyzeCode(args) {
    const { path, type = 'quality' } = args;
    
    // Placeholder for code analysis - integrate with static analysis tools
    const analysisCommands = {
      security: `semgrep --config=auto ${path}`,
      performance: `eslint ${path} --rule 'complexity: [error, 10]'`,
      quality: `sonarjs ${path}`
    };
    
    try {
      const { stdout } = await execAsync(analysisCommands[type] || analysisCommands.quality);
      return {
        content: [{
          type: 'text',
          text: `Code analysis results for ${path}:\n\n${stdout}`
        }]
      };
    } catch (error) {
      return {
        content: [{
          type: 'text',
          text: `Analysis completed with findings:\n${error.stdout || error.message}`
        }]
      };
    }
  }

  async start() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.log('Claude MCP Server started');
  }
}

// Start the server
const server = new ClaudeMCPServer();
server.start().catch(console.error);
``` 