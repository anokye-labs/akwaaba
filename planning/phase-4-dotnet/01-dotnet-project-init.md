# Feature: Create .NET Console Application

**ID:** dotnet-project-init  
**Phase:** 4 - Example Application  
**Status:** Pending  
**Dependencies:** repo-init

## Overview
Initialize a simple .NET 9 console application that demonstrates how agents can maintain code in an issue-driven workflow.

## Key Tasks
- Run dotnet new console in src/Akwaaba.Example/
- Create solution file: dotnet new sln
- Add project to solution
- Configure project properties (nullable reference types, etc.)
- Add basic Program.cs with example functionality
- Create src/README.md explaining purpose
- Add .editorconfig for C# conventions
- Build and verify project compiles
- Commit: "feat(dotnet): Initialize example application"
