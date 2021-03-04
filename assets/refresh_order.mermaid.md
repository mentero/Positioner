graph LR
  subgraph init ["Current state"]
    a1["Apple [1]"]
    a2["Banana [2]"]
    a3["Orange [3]"]
  end
  subgraph repo_insert ["Repo insert"]
    b1["Apple [1]"]
    b2["Banana [2]"]
    x1["Watermelon [3]"]
    style x1 stroke:green,fill:lightgreen
    b3["Orange [3]"]
  end
  a1 --> b1
  a2 --> b2
  a3 --> b3
  subgraph ordered ["refresh_order!/3"]
    c1["Apple [1]"]
    c2["Banana [2]"]
    x2["Watermelon [3]"]
    style x2 stroke:green,fill:lightgreen
    c3["Orange [4]"]
  end
  b1 --> c1
  b2 --> c2
  b3 --> c3
  x1 --> x2
