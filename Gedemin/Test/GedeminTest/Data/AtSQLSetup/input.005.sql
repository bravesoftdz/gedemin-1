select
  iif((case
  
      case 1
        when 1 then 10
        when 2 then 20
      else
        30
      end
  
    when 1 then
    
      case 1
        when 1 then 10
        when 2 then 20
      else
        30
      end
      
    when 2 then 20
  else
      case 1
        when 1 then 10
        when 2 then 20
      else
        30
      end
  end) = 10, 1, 0)
from
  rdb$database