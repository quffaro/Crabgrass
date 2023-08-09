############################################
## PLOTTING
############################################
function color(agent)
    @match agent.type begin 
        :crab   => @match agent.status.status begin 
            :dead     => :grey
            :eating   => :red
            _         => :red
        end
        :grass  => @match agent.status.status begin
            :growing   => :green 
            :defending => :orange
            _          => :green
        end
        :fungus => @match agent.status.status begin
            :spore    => :yellow
            :fruiting => :orange
            _         => :orange
        end
        _             => :grey
    end
end

function marker(agent)
    @match agent.type begin
        :grass => '✿'
        :fungus => @match agent.status.status begin 
            :spore => :rect 
            :fruiting => :circle
        end
        :crab => if agent.age >= 10
            :rect
        else
            :circle
        end  
        _      => :rect
    end
end

function agent_size(agent)
    @match agent.type begin
        :crab   => 5
        :grass  => 5
        :fungus => @match agent.status.status begin 
            :spore => 3
            :fruiting => 5
        end
        _       => 0
    end 
end

