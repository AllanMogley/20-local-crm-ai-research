I'm conducting a research on local AI llms and their efectiveness over cloud models in CRM applications
I'm working on Twenty CRM and using its MCP server and tools running on localhost
I'm also working on tau-bench.
I need to create a custom CRM domain in tau-bench that is connected to my Twenty crm running on port 3000
Twenty has a postgres DB running on port 5432
During testing different models on the crm domain, tau should be able to connect to Twenty via the mcp and perform actions
that I will check in the Web UI.

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