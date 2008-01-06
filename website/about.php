<div class='main_box'>
  <div class='main_box_head'>
    <span class='main_head'>About Anna^</span>
  </div>
  <div class='main_box_content'>
  <p>Anna^ was originally created to replace a headless irssi-session with some 
  scripts. The first versions used the Net::IRC perl-module, but from v0.40 we
  decided to switch to the POE framework, which allows for greater flexibility 
  and additional features.</p>
  <p>Anna^ is highly modularised and all user-related features have been put in
  individual modules, that can be enabled or disabled at will. A few modules are
  marked as core-modules, and these are necessary for Anna^ to work properly. 
  But none of these modules will send any privmsgs to the channels Anna^ watch per
  default, so Anna^ will remain silent unless additional modules are loaded. This
  is great if you want a lean'n'mean bot that doesn't seek attention.</p>
  <p>By default, Anna^ can do the following:<br />
    <ul>
      <li>Allow users to register</li>
      <li>Keep track of different accesslevels for registered users</li>
      <li>Grant ops/halfops/voices to users with appropriate priviledges</li>
    </ul>
  </p>
  <p>But aside from this, Anna^ ships with a bunch of standard-modules that can 
  be enabled at will. Here's a few of the things you can do:<br />
    <ul>
      <li>Keep notes, search through notes</li>
      <li>Manage a list of quotes</li>
      <li>Get random fortunes/bash quotes/haikus</li>
      <li>Search with google</li>
      <li>Keep track of karma</li>
      <li>Order goodies from the bar ^.^</li>
      <li>Play roulette</li>
      <li>Keep track of when people were last seen in channel</li>
      <li>Insult your friends, play dice, get Anna^ to make up your mind and much
      more</li>
    </ul>
  </p>
  <p>Anna^ is written in perl, and the module-interface makes it easy to create 
  additional modules. At the moment, there are only bindings for perl, but a 
  simple wrapper-script is provided if you prefer to write your modules in a 
  different language. There are no plans to create bindings for other languages
  but if the need arises, we'll look at it.</p>
  </div>
</div>
