**Key Points of Security Co-Pilot for Microsoft**

**Purpose and Goals:**

* Enhances security analysts' productivity by empowering them with generative AI-based assistance integrated within the Microsoft security ecosystem.
* Meets analysts "where they are" by providing embedded experiences within various security tools.
* Offers standalone experiences for in-depth prompt-based interactions with generative AI.

**Core Features and Capabilities:**

**Embedded Experiences:**

* Summarizes incident information and provides guided responses within Defender for Endpoint.
* Analyzes suspicious credentials dumps and provides actionable insights.
* Generates summaries and key security details for devices in InTune and Defender for Endpoint.
* Helps understand complex policies and their impact.
* Enables quick exploration of risky users and automated incident reporting.
* Provides recommendations for storage account public access settings in Defender for Cloud.

**Standalone Experiences:**

* Allows users to interact with generative AI through natural language prompts.
* Utilizes various plugins that connect to external data sources and APIs for enhanced insights.
* Facilitates custom plugin creation using kql for additional flexibility.
* Offers a range of pre-built prompt books to guide users' interactions.
* Enables the chaining of prompts for complex task automation.

**Prompt Engineering and Rag Retrieval:**

* Leverages prompt engineering techniques to enhance generative AI responses.
* Retrieves additional data from logs, events, policies, and other sources using rag retrieval (data augmentation) to provide more comprehensive insights.

**Safety and Governance:**

* Operates within security constraints and regulations.
* Uses "on behalf of" permissions to prevent unauthorized access to data.
* Provides usage reporting and allows for capacity management to ensure responsible consumption.

**Licensing and Pricing:**

* Requires Security Compute Units (SCUs) for generative AI interactions.
* Recommended minimum usage of 3 SCUs per hour for useful interactions.
* Pricing is based on hourly provisioning of SCUs, with options for 1 to 100 SCUs.

**User Roles:**

* Co-pilot Owner: Full access to all capabilities, including capacity management.
* Co-pilot Contributor: Limited access to capabilities but can run prompts and interact with the system.
* Default permissions assign all users the Co-pilot Contributor role.

**Benefits:**

* Increased analyst productivity and efficiency.
* Faster onboarding and upskilling for new analysts.
* Improved understanding of security information and events.
* Automated insights and guidance for complex tasks.
* Enhanced collaboration and knowledge sharing.