Benchmark

Benchmark run from 2026-03-04 10:49:19.039316Z UTC

## System

Benchmark suite executing on the following system:

<table style="width: 1%">
  <tr>
    <th style="width: 1%; white-space: nowrap">Operating System</th>
    <td>macOS</td>
  </tr><tr>
    <th style="white-space: nowrap">CPU Information</th>
    <td style="white-space: nowrap">Apple M4 Pro</td>
  </tr><tr>
    <th style="white-space: nowrap">Number of Available Cores</th>
    <td style="white-space: nowrap">12</td>
  </tr><tr>
    <th style="white-space: nowrap">Available Memory</th>
    <td style="white-space: nowrap">24 GB</td>
  </tr><tr>
    <th style="white-space: nowrap">Elixir Version</th>
    <td style="white-space: nowrap">1.19.1</td>
  </tr><tr>
    <th style="white-space: nowrap">Erlang Version</th>
    <td style="white-space: nowrap">28.1.1</td>
  </tr>
</table>

## Configuration

Benchmark suite executing with the following configuration:

<table style="width: 1%">
  <tr>
    <th style="width: 1%">:time</th>
    <td style="white-space: nowrap">10 s</td>
  </tr><tr>
    <th>:parallel</th>
    <td style="white-space: nowrap">10</td>
  </tr><tr>
    <th>:warmup</th>
    <td style="white-space: nowrap">2 s</td>
  </tr>
</table>

## Statistics



Run Time

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Average</th>
    <th style="text-align: right">Devitation</th>
    <th style="text-align: right">Median</th>
    <th style="text-align: right">99th&nbsp;%</th>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap; text-align: right">164.37</td>
    <td style="white-space: nowrap; text-align: right">6.08 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;17.91%</td>
    <td style="white-space: nowrap; text-align: right">5.86 ms</td>
    <td style="white-space: nowrap; text-align: right">9.77 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap; text-align: right">154.47</td>
    <td style="white-space: nowrap; text-align: right">6.47 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;17.31%</td>
    <td style="white-space: nowrap; text-align: right">6.28 ms</td>
    <td style="white-space: nowrap; text-align: right">9.90 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">92.83</td>
    <td style="white-space: nowrap; text-align: right">10.77 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;10.46%</td>
    <td style="white-space: nowrap; text-align: right">10.44 ms</td>
    <td style="white-space: nowrap; text-align: right">15.17 ms</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">87.59</td>
    <td style="white-space: nowrap; text-align: right">11.42 ms</td>
    <td style="white-space: nowrap; text-align: right">&plusmn;8.53%</td>
    <td style="white-space: nowrap; text-align: right">11.25 ms</td>
    <td style="white-space: nowrap; text-align: right">14.80 ms</td>
  </tr>

</table>


Run Time Comparison

<table style="width: 1%">
  <tr>
    <th>Name</th>
    <th style="text-align: right">IPS</th>
    <th style="text-align: right">Slower</th>
  <tr>
    <td style="white-space: nowrap">http1 stream</td>
    <td style="white-space: nowrap;text-align: right">164.37</td>
    <td>&nbsp;</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http1 collected</td>
    <td style="white-space: nowrap; text-align: right">154.47</td>
    <td style="white-space: nowrap; text-align: right">1.06x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 collected</td>
    <td style="white-space: nowrap; text-align: right">92.83</td>
    <td style="white-space: nowrap; text-align: right">1.77x</td>
  </tr>

  <tr>
    <td style="white-space: nowrap">http2 stream</td>
    <td style="white-space: nowrap; text-align: right">87.59</td>
    <td style="white-space: nowrap; text-align: right">1.88x</td>
  </tr>

</table>