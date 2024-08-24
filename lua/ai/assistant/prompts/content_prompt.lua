M = {}
M.PROMP = [[{{#language_name}}
Here's a file of {{language_name}} that I'm going to ask you to make an edit to.
{{/language_name}}
{{^language_name}}
Here's a file of text that I'm going to ask you to make an edit to.
{{/language_name}}

{{#is_insert}}
The point you'll need to insert at is marked with <insert_here></insert_here>.
{{/is_insert}}
{{^is_insert}}
The section you'll need to rewrite is marked with <rewrite_this></rewrite_this> tags.
{{/is_insert}}

<document>
{{{document_content}}}
</document>

{{#is_truncated}}
The context around the relevant section has been truncated (possibly in the middle of a line) for brevity.
{{/is_truncated}}

{{#is_insert}}
You can't replace {{content_type}}, your answer will be inserted in place of the `<insert_here></insert_here>` tags. Don't include the insert_here tags in your output.

Generate {{content_type}} based on the following prompt:

<prompt>
{{{user_prompt}}}
</prompt>

Match the indentation in the original file in the inserted {{content_type}}, don't include any indentation on blank lines.

Immediately start with the following format with no remarks:

```
{{=<% %>=}}
{{INSERTED_CODE}}
<%={{ }}=%>
```
{{/is_insert}}
{{^is_insert}}
Edit the section of {{content_type}} in <rewrite_this></rewrite_this> tags based on the following prompt:

<prompt>
{{{user_prompt}}}
</prompt>

{{#rewrite_section}}
And here's the section to rewrite based on that prompt again for reference:

<rewrite_this>
{{{rewrite_section}}}
</rewrite_this>
{{/rewrite_section}}

Only make changes that are necessary to fulfill the prompt, leave everything else as-is. All surrounding {{content_type}} will be preserved.

Start at the indentation level in the original file in the rewritten {{content_type}}. Don't stop until you've rewritten the entire section, even if you have no more changes to make, always write out the whole section with no unnecessary elisions.

Immediately start with the following format with no remarks:

```
{{=<% %>=}}
{{REWRITTEN_CODE}}
<%={{ }}=%>
```
{{/is_insert}}

]]
return M
