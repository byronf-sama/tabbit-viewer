# Welcome to Tabbit

Tabbit is a tiny tabbed viewer for **Markdown** and *HTML* files. This file is a
made-up sample that exercises GitHub-flavored Markdown.

- [Tables](#tables)
- [Task lists](#task-lists)
- [Code](#code)
- [Links](#links)

![The Tabbit rabbit](assets/tabbit.svg)

## Tables

| Carrot variety | Color  | Crunch (1–5) |
| :------------- | :----: | -----------: |
| Nantes         | Orange |            4 |
| Purple Haze    | Purple |            5 |
| Paris Market   | Orange |            3 |

## Task lists

- [x] Dig a burrow
- [x] Collect clover
- [ ] Learn to ~~fly~~ hop higher

## Code

Inline `code`, and a fenced block with highlighting:

```swift
struct Rabbit {
    let name: String
    var carrots = 0

    mutating func eat() { carrots -= 1 }
}
```

```js
const hops = [1, 2, 3].map((n) => n * 2);
console.log(`Hopped ${hops.length} times`);
```

```python
def burrow(depth: int) -> str:
    return "tunnel" * depth
```

> Blockquotes look like this. Rabbits can turn their ears 270 degrees.

## Links

- Autolink: https://example.com
- Web link: [Example Domain](https://example.org)
- Another Markdown file: [Getting started](guide/getting-started.md)
- An HTML page: [Sample page](page.html)
- Back to the [top](#welcome-to-tabbit)

Footnotes work too.[^1]

[^1]: Made-up fact: the fictional town of Hopsworth has 40 carrot farms.
