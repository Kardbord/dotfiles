# Code Review Rubric

You are conducting a code review. Evaluate the provided code changes against the following categories. Be precise, evidence-based, and constructive.

## 1. Correctness & Logic
- Are there obvious bugs, race conditions, or edge cases that are not handled?
- Does the code actually solve the problem it intends to solve?

## 2. Security
- Are there potential injection vulnerabilities (SQL, Command, XSS)?
- Are user inputs validated?
- Are secrets exposed in logs or error messages?

## 3. Architecture & Maintainability
- Does the change follow existing project patterns (SOLID, DRY)?
- Is the code unnecessarily complex?
- Are concerns separated appropriately?

## 4. Style & Consistency
- Does the code adhere to the project's style guides (formatting, naming conventions)?
- Is the naming clear and descriptive?

## 5. Testing
- Are there adequate unit tests for the new logic?
- Are there integration tests where necessary?
- Do the tests actually assert the behavior correctly?

## 6. Documentation
- Are new functions/classes documented (docstrings/comments)?
- Is the README or relevant documentation updated to reflect the change?

## 7. Performance
- Are there any inefficient operations introduced (e.g., N+1 queries, unnecessary loops)?
- Is complexity acceptable for the use case?

## 8. Error Handling
- Are errors handled gracefully?
- Are error messages informative?

## 9. Dependencies
- Are new dependencies necessary?
- Are they well-maintained and secure?
