I'm conducting a research on local AI llms and their efectiveness over cloud models in CRM applications
I'm working on Twenty CRM and using its MCP server and tools running on localhost
I'm also working on tau-bench.
I need to create a custom CRM domain in tau-bench that is connected to my Twenty crm running on port 3000
Twenty has a postgres DB running on port 5432
During testing different models on the crm domain, tau should be able to connect to Twenty via the mcp and perform actions
that I will check in the Web UI.

ARCHITECTURE:
1. Twenty CRM is up and running
    a) The twenty server is running on port 3000, get the server's hostname from the .crm_environment_env file in this directory.
        Read it from the TWENTY_HOSTNAME variable.
    b) The mcp is served on port 3000/mcp
    c) The API key for the server is avalable on the .crm_environment_env file in this directory, read it from the Bearer variable.
    d) Ensuse to go through the mcp directory to understand the structure of the mcp server tools.
    e) Test the mcp to make sure it is reachable and it works.

2. Save the sessions within the sessions directory

INSTRUCTIONS:
1. Help me structure and create the CRM domain in tau-bench.
    a)  Research on this excellent applicable CRM based theory for this exvironment.
        Commitment-Trust Theory (Morgan & Hunt, 1994)
    b)  I should have 10 tasks for this environment.
        Provide a list of the tasks for me first before you get into details.
        I know tau uses an agent and client llm models, I'm thinking of having the below in one of the tasks.
        A stubbon user who is difficult to convert into our customer or lead since he does not trust our business.
        The model should try to convince him and change his mind become our customer.
    c)  Remember that this has to be connected to my Twenty crm server.
        When the model performs actions, it should interact with my Twenty crm server via the mcp.

2. Don't create the domain yet.
    a) I want you to go through the following directory (tau2-bench) to understand the structure of a tau2-bench domain 
        and how to add a custom domain.
3. Create a copy of the tau-bench directory and name it tau2-bench-copy and then add the domain from here.
4. This tau2 domain should use the twenty mcp server as provided above and be able to interact with it.
5. For tau2 to use the mcp, in the copied tau directory, please a .evf file, it should reflect the .env-example file.
   This should expose twenty mcp url and the bearer token, dont hard code these in the domain.
THANKS
