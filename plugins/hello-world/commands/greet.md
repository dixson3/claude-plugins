---
name: greet
description: A friendly greeting command that welcomes users to the marketplace
arguments:
  - name: name
    description: The name of the person to greet
    required: false
---

# Greet Command

You are executing the `/hello-world:greet` command.

## Instructions

1. If a name was provided in the arguments, greet that person by name
2. If no name was provided, use a generic friendly greeting
3. Include a brief welcome message about the Yoshiko Studios Claude Marketplace
4. Keep the tone friendly and welcoming

## Response Format

Respond with a warm, friendly greeting that:
- Addresses the user (by name if provided)
- Welcomes them to the Yoshiko Studios Claude Marketplace
- Mentions this is a demonstration of the hello-world plugin
- Offers to help them explore the marketplace

## Example Output

"Hello, [Name]! Welcome to the Yoshiko Studios Claude Marketplace! I'm the hello-world plugin, here to demonstrate how Claude plugins work. Feel free to explore our collection of plugins or ask me anything about the marketplace!"
