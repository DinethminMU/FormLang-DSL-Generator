%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

void yyerror(const char *message);
int yylex();

char *currentField, *fieldType, *defaultTextarea;
char jsValidation[8192] = ""; // Holds the JavaScript validation logic

// Function to capitalize the first letter of a string
char *capitalize_first_letter(const char *input) {
    char *output = strdup(input);
    if (output && strlen(output) > 0) {
        output[0] = toupper(output[0]);
    }
    return output;
}
%}

%union {
    char *text;
    int number;
}

%token FORM META SECTION FIELD VALIDATE IF ERROR
%token REQ MIN MAX DEFAULT
%token COLON SEMICOLON EQUALS LBRACE RBRACE
%token LBRACK RBRACK COMMA
%token LESS_THAN GREATER_THAN EQUAL_TO
%token <text> NAME STRING BOOL
%token <number> NUMBER

%type <text> attribute_block attribute_list string_array string_elements condition
%type <text> attribute

%%

program:
    FORM NAME LBRACE form_body RBRACE {
        printf("<div class='footer-section'>\n");
        printf("<button type=\"submit\">Submit</button>\n</div>\n</form>\n");

        if (strlen(jsValidation) > 0) {
            printf("<script>\n");
            printf("document.forms['MyForm'].addEventListener('submit', function(e) {\n");
            printf("%s", jsValidation);
            printf("});\n</script>\n");
        }
    }
;

form_body:
    metadata section_list validation_block
;

metadata:
    | metadata META NAME EQUALS STRING SEMICOLON {
        printf("<!-- Meta: %s = %s -->\n", $3, $5);
    }
;

section_list:
    | section_list SECTION NAME LBRACE field_list RBRACE
;

field_list:
    | field_list field
;

field:
    FIELD NAME COLON NAME attribute_block SEMICOLON {
        currentField = $2;
        fieldType = $4;
        char *label = capitalize_first_letter($2);
        printf("<div class='form-input'>");

        if (strcmp($4, "checkbox") == 0) {
            int checked = strstr($5, "checked") != NULL;
            printf("<label><input type=\"checkbox\" name=\"%s\"%s> %s</label>", $2, checked ? " checked" : "", label);
        } else if (strcmp($4, "textarea") == 0) {
            printf("<label>%s:<br><textarea name=\"%s\" %s>%s</textarea></label>", label, $2, $5, defaultTextarea ? defaultTextarea : "");
            free(defaultTextarea); defaultTextarea = NULL;
        } else {
            printf("<label>%s:<br><input type=\"%s\" name=\"%s\" %s></label>", label, $4, $2, $5);
        }

        printf("</div>\n");
        free($5);
        free(label);
    }

    | FIELD NAME COLON NAME {
        currentField = $2;
        fieldType = $4;
    } string_array attribute_block SEMICOLON {
        char *label = capitalize_first_letter($2);
        printf("<div class='form-input'>");

        if (strcmp($4, "radio") == 0) {
            printf("<label>%s:</label><br>%s", label, $6);
        } else if (strcmp($4, "dropdown") == 0) {
            printf("<label>%s:<br><select name=\"%s\" %s>%s</select></label>", label, $2, $7, $6);
        }

        printf("</div>\n");
        free($6); free($7); free(label);
    }
;

validation_block:
    | VALIDATE LBRACE validations RBRACE
;

validations:
    | validations IF condition LBRACE ERROR STRING SEMICOLON RBRACE {
        char buffer[512];
        sprintf(buffer, "if ((%s)) { e.preventDefault(); alert(\"%s\"); }\n", $3, $6);
        strcat(jsValidation, buffer);
    }
;

condition:
    NAME LESS_THAN NUMBER {
        char buffer[128];
        sprintf(buffer, "Number(document.forms['MyForm'].elements['%s'].value) < %d", $1, $3);
        $$ = strdup(buffer);
    }
  | NAME GREATER_THAN NUMBER {
        char buffer[128];
        sprintf(buffer, "Number(document.forms['MyForm'].elements['%s'].value) > %d", $1, $3);
        $$ = strdup(buffer);
    }
  | NAME EQUAL_TO NUMBER {
        char buffer[128];
        sprintf(buffer, "Number(document.forms['MyForm'].elements['%s'].value) == %d", $1, $3);
        $$ = strdup(buffer);
    }
;

attribute_block:
    /* empty */ { $$ = strdup(""); }
  | attribute_list  { $$ = $1; }
;

attribute_list:
    attribute                { $$ = $1; }
  | attribute_list attribute  {
        $$ = malloc(strlen($1) + strlen($2) + 2);
        sprintf($$, "%s %s", $1, $2);
        free($1); free($2);
    }
;

attribute:
    REQ                             { $$ = strdup("required"); }
  | MIN EQUALS NUMBER                { char buffer[32]; sprintf(buffer, "min=\"%d\"", $3); $$ = strdup(buffer); }
  | MAX EQUALS NUMBER                { char buffer[32]; sprintf(buffer, "max=\"%d\"", $3); $$ = strdup(buffer); }
  | MIN EQUALS STRING                { char buffer[64]; sprintf(buffer, "min=\"%s\"", $3); $$ = strdup(buffer); }
  | MAX EQUALS STRING                { char buffer[64]; sprintf(buffer, "max=\"%s\"", $3); $$ = strdup(buffer); }
  | DEFAULT EQUALS STRING                {
        if (strcmp(fieldType, "textarea") == 0) {
            defaultTextarea = strdup($3); $$ = strdup("");
        } else {
            char buffer[256]; sprintf(buffer, "value=\"%s\"", $3); $$ = strdup(buffer);
        }
    }
  | DEFAULT EQUALS BOOL                  { $$ = strdup(strcmp($3, "true") == 0 ? "checked" : ""); }
  | NAME EQUALS NUMBER                   { char buffer[64]; sprintf(buffer, "%s=\"%d\"", $1, $3); $$ = strdup(buffer); }
  | NAME EQUALS STRING                   { char buffer[256]; sprintf(buffer, "%s=\"%s\"", $1, $3); $$ = strdup(buffer); }
;

string_array:
    LBRACK string_elements RBRACK { $$ = $2; }
;

string_elements:
    STRING {
        char buffer[256];
        if (strcmp(fieldType, "radio") == 0)
            sprintf(buffer, "<input type=\"radio\" name=\"%s\" value=\"%s\"> %s<br>\n", currentField, $1, $1);
        else
            sprintf(buffer, "<option value=\"%s\">%s</option>\n", $1, $1);
        $$ = strdup(buffer);
    }
  | string_elements COMMA STRING {
        char *combined = malloc(strlen($1) + 256);
        if (strcmp(fieldType, "radio") == 0)
            sprintf(combined, "%s<input type=\"radio\" name=\"%s\" value=\"%s\"> %s<br>\n", $1, currentField, $3, $3);
        else
            sprintf(combined, "%s<option value=\"%s\">%s</option>\n", $1, $3, $3);
        free($1); $$ = combined;
    }
;

%%
int main() {
    printf("<style>"
        "body { background: #f2f2f2; font-family: 'Times New Roman', serif; }"  // Set font to Times New Roman
        ".form-container {"
        "  background: #add8e6; max-width: 600px; margin: 40px auto; padding: 30px;"  // Light blue background
        "  border-radius: 10px; box-shadow: 0 4px 12px rgba(0,0,0,0.1);"
        "}"
        ".form-container label { display: block; font-weight: 500; margin-bottom: 6px; color: #333; }"
        ".form-container input[type='text'], .form-container input[type='password'],"
        ".form-container input[type='number'], .form-container input[type='email'],"
        ".form-container input[type='date'], .form-container select, .form-container textarea {"
        "  width: 100%%; padding: 10px; margin-bottom: 16px; border: 1px solid #ccc; border-radius: 4px; font-size: 14px;"
        "}"
        ".form-container button { padding: 10px 20px; background-color: #e74c3c; border: none;"  // Red submit button
        "  border-radius: 4px; color: white; font-size: 16px; cursor: pointer; }"
        ".form-container button:hover { background-color: #c0392b; }"  // Darker red on hover
        "</style>");
    printf("<form name=\"MyForm\" class=\"form-container\">\n");
    return yyparse();
}





void yyerror(const char *message) {
    fprintf(stderr, "Error: %s\n", message);
}
