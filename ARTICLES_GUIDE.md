# Articles System Guide

## Overview
The articles system allows you to add SEO-friendly blog posts and guides to your PC Upgrade Advisor website.

## Files Created
1. **articles.html** - Public-facing page that displays all articles
2. **article-editor.html** - Editor interface for creating new articles
3. **data/articles.json** - JSON file that stores all article data

## How to Add a New Article

### Method 1: Using the Article Editor (Recommended)

1. Open `article-editor.html` in your browser
2. Fill in all the article details:
   - **Title**: The main heading of your article
   - **Excerpt**: A brief summary (2-3 sentences) that appears in the article list
   - **Content**: The full article content using HTML formatting
   - **Author**: Your name (optional)
   - **Read Time**: Estimated reading time in minutes
   - **Tags**: Keywords to categorize your article (e.g., "CPU", "Gaming", "Budget")

3. Click "Update Preview" to see how your article will look

4. When satisfied, click "Export Article JSON"

5. The article will download as a JSON file

6. Open `data/articles.json` in your code editor

7. Copy the contents of the downloaded JSON file

8. Paste it into the articles array in `articles.json` (remember to add commas between articles)

### Example articles.json structure:
```json
[
  {
    "id": "first-article",
    "title": "First Article",
    ...
  },
  {
    "id": "second-article",
    "title": "Second Article",
    ...
  }
]
```

### Method 2: Manual JSON Editing

You can also manually edit `data/articles.json` directly. Each article should have this structure:

```json
{
  "id": "url-friendly-article-id",
  "title": "Article Title",
  "excerpt": "Brief summary of the article",
  "content": "<h2>Section</h2><p>Article content with HTML tags...</p>",
  "date": "2026-02-12",
  "author": "Author Name",
  "readTime": 5,
  "tags": ["Tag1", "Tag2"]
}
```

## HTML Formatting Tips

The content field supports HTML. Common tags to use:

- `<h2>Main Section</h2>` - For major sections
- `<h3>Sub-section</h3>` - For sub-sections
- `<p>Paragraph text</p>` - For paragraphs
- `<ul><li>Item</li></ul>` - For bullet lists
- `<ol><li>Item</li></ol>` - For numbered lists
- `<strong>Bold text</strong>` - For emphasis
- `<em>Italic text</em>` - For emphasis
- `<a href="url">Link text</a>` - For links

## SEO Benefits

Articles help improve your website's SEO by:
- Providing valuable content that search engines can index
- Using relevant keywords naturally in your articles
- Creating internal and external linking opportunities
- Increasing time visitors spend on your site
- Establishing authority in PC hardware topics

## Article Ideas

Consider writing articles about:
- "Best CPU Upgrades for Gaming in 2026"
- "How to Choose the Right Graphics Card"
- "Understanding RAM Speed and Capacity"
- "Budget PC Upgrade Guide: $200 vs $500 vs $1000"
- "CPU vs GPU: Which Upgrade Gives Better Performance?"
- "Common PC Bottlenecks and How to Fix Them"
- "DDR4 vs DDR5: Is It Worth Upgrading?"
- "Gaming Performance: CPU or GPU Priority?"

## Navigation

The articles page is linked:
- In the header of the main page (prominent button)
- In the footer navigation
- Accessible at `articles.html`

## Viewing Articles

- Articles are displayed in reverse chronological order (newest first)
- Each article shows title, excerpt, metadata, and tags
- Clicking an article opens it in full view
- URL includes the article ID for sharing (e.g., `articles.html?article=article-id`)

## Tips for Good Articles

1. **Use descriptive titles** - Include relevant keywords
2. **Write compelling excerpts** - This appears in search results
3. **Structure with headings** - Use H2 and H3 tags for sections
4. **Add relevant tags** - Helps with organization and SEO
5. **Include lists** - Makes content scannable
6. **Keep paragraphs short** - Improves readability
7. **Update regularly** - Fresh content helps SEO

## Support

For questions or issues, refer to the main project documentation or contact via the email in the footer.
